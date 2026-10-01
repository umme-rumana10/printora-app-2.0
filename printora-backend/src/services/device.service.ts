import jwt from 'jsonwebtoken';
import { config } from '../config';
import { SupabaseService } from './supabase.service';
import { StateMachineService } from './state-machine.service';
import { FileService } from './file.service';
import { Job, JobStatus } from '../types';

export class DeviceService {
  private static instance: DeviceService;
  private db: SupabaseService;
  private stateMachine: StateMachineService;
  private fileService: FileService;

  private constructor() {
    this.db = SupabaseService.getInstance();
    this.stateMachine = StateMachineService.getInstance();
    this.fileService = FileService.getInstance();
  }

  public static getInstance(): DeviceService {
    if (!DeviceService.instance) {
      DeviceService.instance = new DeviceService();
    }
    return DeviceService.instance;
  }

  public authenticateDevice(machineId: string, secretKey: string): string {
    // In production, compare with machine secret stored in DB
    const token = jwt.sign(
      { machineId, role: 'device' },
      config.jwt.secret,
      { expiresIn: '30d' }
    );
    return token;
  }

  public verifyDeviceToken(token: string): { machineId: string } {
    try {
      const decoded = jwt.verify(token, config.jwt.secret) as any;
      if (decoded.role !== 'device') throw new Error('Not a device token');
      return { machineId: decoded.machineId };
    } catch (err: any) {
      throw new Error(`Device authentication failed: ${err.message}`);
    }
  }

  public async getPendingJobs(machineId: string): Promise<Job[]> {
    const all = await this.db.getAllJobs();
    return all.filter(j => j.machine_id === machineId && (j.status === 'ASSIGNED_TO_MACHINE' || j.status === 'DOWNLOADING'));
  }

  public async updateJobProgress(jobId: string, machineId: string, status: JobStatus, details?: any): Promise<Job> {
    const job = await this.db.getJob(jobId);
    if (!job) throw new Error(`Job not found: ${jobId}`);
    if (job.machine_id !== machineId) throw new Error(`Machine mismatch for job: ${jobId}`);

    const updatedJob = await this.stateMachine.transition(jobId, status, details);

    // If job is completed, perform file cleanup
    if (status === 'COMPLETED' && job.file_id) {
      const fileRecord = await this.db.getFile(job.file_id);
      if (fileRecord) {
        await this.fileService.cleanupJobFiles(fileRecord);
      }
    }

    return updatedJob;
  }
}
