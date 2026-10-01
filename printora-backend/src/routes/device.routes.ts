import { Router, Request, Response } from 'express';
import { DeviceService } from '../services/device.service';
import { SupabaseService } from '../services/supabase.service';
import { FileService } from '../services/file.service';
import { JobStatus } from '../types';

const router = Router();
const deviceService = DeviceService.getInstance();
const db = SupabaseService.getInstance();
const fileService = FileService.getInstance();

// Middleware to authenticate device JWT
function authenticateDeviceHeader(req: Request, res: Response, next: Function) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Device token required in Authorization header' });
    return;
  }
  const token = authHeader.split(' ')[1];
  try {
    const { machineId } = deviceService.verifyDeviceToken(token);
    (req as any).machineId = machineId;
    next();
  } catch (err: any) {
    res.status(403).json({ error: err.message });
  }
}

// 1. POST /device/auth
router.post('/auth', async (req: Request, res: Response): Promise<void> => {
  try {
    const { machineId, secretKey } = req.body;
    if (!machineId) {
      res.status(400).json({ error: 'machineId is required' });
      return;
    }

    const machine = await db.getMachine(machineId);
    if (!machine) {
      res.status(404).json({ error: `Machine ${machineId} not registered` });
      return;
    }

    const token = deviceService.authenticateDevice(machineId, secretKey || 'default_secret');
    res.json({
      token,
      machineId: machine.id,
      expiresIn: '30d'
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// 2. GET /device/jobs/pending
router.get('/jobs/pending', authenticateDeviceHeader, async (req: Request, res: Response): Promise<void> => {
  try {
    const machineId = (req as any).machineId;
    const pendingJobs = await deviceService.getPendingJobs(machineId);
    res.json({ jobs: pendingJobs });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// 3. GET /device/jobs/:id/download
// Downloads the PDF file over HTTPS using the short-lived signed token
router.get('/jobs/:id/download', async (req: Request, res: Response): Promise<void> => {
  try {
    const jobId = req.params.id;
    const token = (req.query.token as string) || (req.headers.authorization?.replace('Bearer ', ''));

    if (!token) {
      res.status(401).json({ error: 'Missing short-lived download token' });
      return;
    }

    // Verify token
    const tokenData = fileService.verifyDownloadToken(token);
    if (tokenData.jobId !== jobId) {
      res.status(403).json({ error: 'Token does not match requested job ID' });
      return;
    }

    const job = await db.getJob(jobId);
    if (!job || !job.file_id) {
      res.status(404).json({ error: 'Job or file record not found' });
      return;
    }

    const fileRecord = await db.getFile(job.file_id);
    if (!fileRecord) {
      res.status(404).json({ error: 'File record not found' });
      return;
    }

    const fileBuffer = await fileService.getFileBuffer(fileRecord);

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${fileRecord.original_filename}"`);
    res.setHeader('X-File-SHA256', fileRecord.sha256);
    res.setHeader('Content-Length', fileBuffer.length);
    res.send(fileBuffer);
  } catch (err: any) {
    res.status(403).json({ error: `Download failed: ${err.message}` });
  }
});

// 4. POST /device/jobs/:id/status
// Status updates reported from Raspberry Pi: DOWNLOADING -> READY_TO_PRINT -> PRINTING -> COMPLETED
router.post('/jobs/:id/status', authenticateDeviceHeader, async (req: Request, res: Response): Promise<void> => {
  try {
    const jobId = String(req.params.id);
    const machineId = (req as any).machineId;
    const { status, details } = req.body;

    if (!status) {
      res.status(400).json({ error: 'status is required' });
      return;
    }

    const updatedJob = await deviceService.updateJobProgress(
      jobId,
      machineId,
      status as JobStatus,
      details
    );

    res.json({
      success: true,
      job: updatedJob
    });
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
});

// 5. POST /device/machines/:id/heartbeat
router.post('/machines/:id/heartbeat', async (req: Request, res: Response): Promise<void> => {
  try {
    const machineId = String(req.params.id);
    const { paper_status, ink_status, printer_status } = req.body;

    const updated = await db.updateMachineTelemetry(machineId, {
      status: 'ONLINE',
      ...(paper_status && { paper_status }),
      ...(ink_status && { ink_status }),
      ...(printer_status && { printer_status })
    });

    res.json({ success: true, machine: updated });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
