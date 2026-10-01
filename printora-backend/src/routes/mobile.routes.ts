import { Router, Request, Response } from 'express';
import multer from 'multer';
import crypto from 'crypto';
import { SupabaseService } from '../services/supabase.service';
import { StateMachineService } from '../services/state-machine.service';
import { FileService } from '../services/file.service';
import { PaymentService } from '../services/payment.service';
import { Job } from '../types';
import { config } from '../config';

const router = Router();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 25 * 1024 * 1024 } });
const db = SupabaseService.getInstance();
const stateMachine = StateMachineService.getInstance();
const fileService = FileService.getInstance();
const paymentService = PaymentService.getInstance();

// 0. GET /machines
// Returns list of all registered machines for mobile kiosk selection
router.get('/machines', async (_req: Request, res: Response): Promise<void> => {
  try {
    const machines = await db.getAllMachines();
    res.json({ machines });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// 1. GET /machines/:id/status
router.get('/machines/:id/status', async (req: Request, res: Response): Promise<void> => {
  try {
    const machineId = String(req.params.id);
    const machine = await db.getMachine(machineId);
    if (!machine) {
      res.status(404).json({ error: 'Machine not found' });
      return;
    }

    const isAvailable =
      machine.status === 'ONLINE' &&
      machine.paper_status !== 'OUT' &&
      machine.printer_status !== 'ERROR' &&
      !machine.maintenance_mode;

    res.json({
      machine,
      isAvailable,
      canAcceptJobs: isAvailable
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// 2. POST /jobs
// Creates initial job in 'CREATED' state with machine_id and print settings
router.post('/jobs', async (req: Request, res: Response): Promise<void> => {
  try {
    const { machineId, copies = 1, color = false, duplex = false } = req.body;
    if (!machineId) {
      res.status(400).json({ error: 'machineId is required' });
      return;
    }

    const machine = await db.getMachine(machineId);
    if (!machine) {
      res.status(404).json({ error: `Machine ${machineId} does not exist` });
      return;
    }

    if (machine.status !== 'ONLINE' || machine.paper_status === 'OUT' || machine.maintenance_mode) {
      res.status(400).json({ error: 'Machine is currently unavailable for printing' });
      return;
    }

    const jobId = crypto.randomUUID();
    const job: Job = {
      id: jobId,
      machine_id: machineId,
      pages: 1, // Will be updated on upload
      copies: Math.max(1, parseInt(copies, 10) || 1),
      color: Boolean(color),
      duplex: Boolean(duplex),
      amount: 0,
      status: 'CREATED',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };

    await db.saveJob(job);
    db.recordJobEvent(jobId, undefined, 'CREATED', { machineId });

    res.status(201).json({ job });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// 3. POST /jobs/:id/upload
// Accepts single PDF or Image, converts image to PDF, counts pages, computes SHA-256, transitions to 'UPLOADED'
router.post('/jobs/:id/upload', upload.single('file'), async (req: Request, res: Response): Promise<void> => {
  try {
    const jobId = String(req.params.id);
    const job = await db.getJob(jobId);
    if (!job) {
      res.status(404).json({ error: 'Job not found' });
      return;
    }

    if (!req.file) {
      res.status(400).json({ error: 'No file uploaded. Expected field name: file' });
      return;
    }

    // Process file
    const fileRecord = await fileService.processUpload(
      req.file.buffer,
      req.file.originalname,
      req.file.mimetype
    );

    // Calculate price based on verified page count & copies
    const ratePerPage = job.color ? config.pricing.colorPerPage : config.pricing.bwPerPage;
    const totalAmount = fileRecord.page_count * job.copies * ratePerPage;

    job.file_id = fileRecord.id;
    job.pages = fileRecord.page_count;
    job.amount = totalAmount;

    await db.saveJob(job);
    await stateMachine.transition(jobId, 'UPLOADED', {
      fileId: fileRecord.id,
      pages: fileRecord.page_count,
      amount: totalAmount,
      sha256: fileRecord.sha256
    });

    res.json({
      success: true,
      job,
      file: {
        id: fileRecord.id,
        filename: fileRecord.original_filename,
        pages: fileRecord.page_count,
        sha256: fileRecord.sha256
      }
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// 4. POST /jobs/:id/payment-session
// Prepares Razorpay Sandbox order and transitions job from UPLOADED -> AWAITING_PAYMENT -> PAYMENT_PENDING
router.post('/jobs/:id/payment-session', async (req: Request, res: Response): Promise<void> => {
  try {
    const jobId = String(req.params.id);
    const job = await db.getJob(jobId);
    if (!job) {
      res.status(404).json({ error: 'Job not found' });
      return;
    }

    if (job.status === 'CREATED') {
      res.status(400).json({ error: 'Cannot pay for job before uploading document' });
      return;
    }

    if (job.status === 'UPLOADED') {
      await stateMachine.transition(jobId, 'AWAITING_PAYMENT');
    }

    // Create payment order
    const order = await paymentService.createPaymentOrder(jobId, job.amount);
    await stateMachine.transition(jobId, 'PAYMENT_PENDING', { orderId: order.orderId });

    res.json({
      orderId: order.orderId,
      amount: order.amount,
      currency: order.currency,
      keyId: config.razorpay.keyId,
      jobId: job.id
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// 5. GET /jobs/:id/status
// Real-time status check for the mobile tracking screen
router.get('/jobs/:id/status', async (req: Request, res: Response): Promise<void> => {
  try {
    const jobId = String(req.params.id);
    const job = await db.getJob(jobId);
    if (!job) {
      res.status(404).json({ error: 'Job not found' });
      return;
    }

    const machine = await db.getMachine(job.machine_id);
    let fileInfo = null;
    if (job.file_id) {
      const fileRecord = await db.getFile(job.file_id);
      if (fileRecord) {
        fileInfo = {
          filename: fileRecord.original_filename,
          pages: fileRecord.page_count
        };
      }
    }

    res.json({
      job,
      machine: machine ? { id: machine.id, location: machine.location, status: machine.status } : null,
      file: fileInfo
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
