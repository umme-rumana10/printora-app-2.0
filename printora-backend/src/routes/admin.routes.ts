import { Router, Request, Response } from 'express';
import { SupabaseService } from '../services/supabase.service';
import { PaymentService } from '../services/payment.service';

const router = Router();
const db = SupabaseService.getInstance();
const paymentService = PaymentService.getInstance();

// 1. GET /admin/machines
router.get('/machines', async (_req: Request, res: Response): Promise<void> => {
  try {
    const machines = await db.getAllMachines();
    res.json({ machines });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// 2. GET /admin/jobs
router.get('/jobs', async (_req: Request, res: Response): Promise<void> => {
  try {
    const jobs = await db.getAllJobs();
    res.json({ jobs });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// 3. POST /admin/jobs/:id/refund
router.post('/jobs/:id/refund', async (req: Request, res: Response): Promise<void> => {
  try {
    const jobId = String(req.params.id);
    const { reason = 'Admin initiated refund' } = req.body;
    const result = await paymentService.refundJob(jobId, reason);
    res.json(result);
  } catch (err: any) {
    res.status(400).json({ error: err.message });
  }
});

// 4. POST /admin/machines/:id/maintenance
router.post('/machines/:id/maintenance', async (req: Request, res: Response): Promise<void> => {
  try {
    const machineId = String(req.params.id);
    const { maintenanceMode } = req.body;
    const updated = await db.updateMachineTelemetry(machineId, {
      maintenance_mode: Boolean(maintenanceMode),
      status: maintenanceMode ? 'MAINTENANCE' : 'ONLINE'
    });
    res.json({ success: true, machine: updated });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
