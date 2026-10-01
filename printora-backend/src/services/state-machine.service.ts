import { Job, JobStatus } from '../types';
import { SupabaseService } from './supabase.service';

// Strict State Transition Matrix
const ALLOWED_TRANSITIONS: Record<JobStatus, JobStatus[]> = {
  CREATED: ['UPLOADED', 'CANCELLED'],
  UPLOADED: ['AWAITING_PAYMENT', 'CANCELLED', 'EXPIRED'],
  AWAITING_PAYMENT: ['PAYMENT_PENDING', 'CANCELLED', 'EXPIRED'],
  PAYMENT_PENDING: ['PAID', 'FAILED', 'EXPIRED'],
  PAID: ['ASSIGNED_TO_MACHINE', 'REFUNDED'],
  ASSIGNED_TO_MACHINE: ['DOWNLOADING', 'FAILED', 'REFUNDED'],
  DOWNLOADING: ['READY_TO_PRINT', 'FAILED', 'REFUNDED'],
  READY_TO_PRINT: ['PRINTING', 'FAILED', 'REFUNDED'],
  PRINTING: ['COMPLETED', 'FAILED'],
  COMPLETED: ['REFUNDED'], // Admin-initiated post-delivery refund
  FAILED: ['REFUNDED'],
  CANCELLED: [],
  EXPIRED: [],
  REFUNDED: []
};

export class StateMachineService {
  private static instance: StateMachineService;
  private db: SupabaseService;

  private constructor() {
    this.db = SupabaseService.getInstance();
  }

  public static getInstance(): StateMachineService {
    if (!StateMachineService.instance) {
      StateMachineService.instance = new StateMachineService();
    }
    return StateMachineService.instance;
  }

  public canTransition(current: JobStatus, next: JobStatus): boolean {
    const allowed = ALLOWED_TRANSITIONS[current] || [];
    return allowed.includes(next);
  }

  public async transition(jobId: string, nextStatus: JobStatus, payload?: any): Promise<Job> {
    const job = await this.db.getJob(jobId);
    if (!job) {
      throw new Error(`Job not found: ${jobId}`);
    }

    if (job.status === nextStatus) {
      return job; // Idempotent
    }

    if (!this.canTransition(job.status, nextStatus)) {
      throw new Error(`Invalid state transition from ${job.status} to ${nextStatus} for job ${jobId}`);
    }

    const previousStatus = job.status;
    job.status = nextStatus;

    if (nextStatus === 'PAID' && !job.paid_at) {
      job.paid_at = new Date().toISOString();
    }

    if (nextStatus === 'COMPLETED' && !job.completed_at) {
      job.completed_at = new Date().toISOString();
    }

    await this.db.saveJob(job);
    this.db.recordJobEvent(jobId, previousStatus, nextStatus, payload);

    console.log(`🔄 [State Machine] Job ${jobId}: ${previousStatus} -> ${nextStatus}`);
    return job;
  }
}
