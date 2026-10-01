import { Router, Request, Response } from 'express';
import { PaymentService } from '../services/payment.service';
import { StateMachineService } from '../services/state-machine.service';
import { SupabaseService } from '../services/supabase.service';
import { FileService } from '../services/file.service';
import { MqttService } from '../services/mqtt.service';
import { config } from '../config';

const router = Router();
const paymentService = PaymentService.getInstance();
const stateMachine = StateMachineService.getInstance();
const db = SupabaseService.getInstance();
const fileService = FileService.getInstance();
const mqttService = MqttService.getInstance();

// POST /webhooks/payment
router.post('/payment', async (req: Request, res: Response): Promise<void> => {
  try {
    const signature = req.headers['x-razorpay-signature'] as string;
    const rawPayload = JSON.stringify(req.body);

    // 1. Verify Signature
    const isValid = paymentService.verifyWebhookSignature(rawPayload, signature);
    if (!isValid) {
      console.warn('❌ [Webhook] Rejected invalid Razorpay signature');
      res.status(400).json({ error: 'Invalid webhook signature' });
      return;
    }

    const { event, payload } = req.body;
    const eventId = req.headers['x-razorpay-event-id'] as string || `evt_${Date.now()}`;
    const paymentEntity = payload?.payment?.entity;
    const orderId = paymentEntity?.order_id || req.body.order_id;
    const paymentId = paymentEntity?.id || req.body.payment_id || `pay_${Date.now()}`;

    if (!orderId) {
      res.status(400).json({ error: 'Missing order_id in webhook payload' });
      return;
    }

    const isCaptured = event === 'payment.captured' || req.body.status === 'captured';

    // 2. Process payment state update
    const result = await paymentService.handlePaymentWebhook(
      eventId,
      orderId,
      paymentId,
      isCaptured ? 'captured' : 'failed'
    );

    if (!result.success || !result.jobId) {
      res.status(400).json(result);
      return;
    }

    // Idempotency: webhook already processed — return current job state without re-transitioning
    if (result.message === 'Already processed') {
      const existingJob = await db.getJob(result.jobId);
      res.json({
        status: 'ok',
        jobId: result.jobId,
        orderId,
        jobStatus: existingJob?.status || 'UNKNOWN',
        message: 'Already processed'
      });
      return;
    }

    const jobId = result.jobId;
    const job = await db.getJob(jobId);
    if (!job || !job.file_id) {
      res.status(500).json({ error: 'Job or file record missing after payment' });
      return;
    }

    const fileRecord = await db.getFile(job.file_id);
    if (!fileRecord) {
      res.status(500).json({ error: 'File record missing' });
      return;
    }

    // 3. Generate short-lived signed download token
    const { token, expiresAt } = fileService.generateShortLivedDownloadToken(
      fileRecord.id,
      job.id,
      job.machine_id
    );

    job.download_token = token;
    job.download_token_expires_at = expiresAt;
    await db.saveJob(job);

    // 4. Transition to ASSIGNED_TO_MACHINE
    await stateMachine.transition(job.id, 'ASSIGNED_TO_MACHINE', {
      machineId: job.machine_id,
      downloadTokenExpiresAt: expiresAt
    });

    // 5. Publish MQTT Job Assignment to Machine (QoS 1)
    const downloadUrl = `${config.publicUrl}/device/jobs/${job.id}/download?token=${token}`;
    try {
      await mqttService.publishJobAssignment(job.machine_id, {
        jobId: job.id,
        downloadUrl,
        downloadToken: token,
        checksum: fileRecord.sha256,
        settings: {
          pages: job.pages,
          copies: job.copies,
          color: job.color,
          duplex: job.duplex
        }
      });
    } catch (mqttErr: any) {
      console.warn(`⚠️ [Webhook] Could not deliver MQTT assignment immediately: ${mqttErr.message}`);
    }

    res.json({
      status: 'ok',
      jobId: job.id,
      orderId,
      jobStatus: 'ASSIGNED_TO_MACHINE'
    });
  } catch (err: any) {
    console.error('❌ [Webhook Error]:', err.message);
    res.status(500).json({ error: err.message });
  }
});

export default router;
