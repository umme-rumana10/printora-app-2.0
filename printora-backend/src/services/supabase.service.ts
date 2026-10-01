import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { config } from '../config';
import { Machine, Job, FileRecord, Payment, JobStatus } from '../types';
import fs from 'fs';
import path from 'path';

export class SupabaseService {
  private static instance: SupabaseService;
  private client?: SupabaseClient;
  private isConnected = false;

  // In-Memory fallback store for offline simulation / local tests
  public machines: Map<string, Machine> = new Map();
  public jobs: Map<string, Job> = new Map();
  public files: Map<string, FileRecord> = new Map();
  public payments: Map<string, Payment> = new Map();
  public jobEvents: Array<{ id: string; job_id: string; from_status?: string; to_status: string; payload: any; created_at: string }> = [];
  public machineEvents: Array<{ id: string; machine_id: string; event_type: string; payload: any; created_at: string }> = [];

  // Local file storage fallback
  public localUploadDir: string;

  private constructor() {
    this.localUploadDir = path.resolve(__dirname, '../../uploads');
    if (!fs.existsSync(this.localUploadDir)) {
      fs.mkdirSync(this.localUploadDir, { recursive: true });
    }

    // Seed default machine
    this.machines.set('printer001', {
      id: 'printer001',
      location: 'Tech Hub Center - Main Lobby Kiosk',
      status: 'ONLINE',
      mqtt_client_id: 'client_printer001',
      last_seen_at: new Date().toISOString(),
      paper_status: 'OK',
      ink_status: 'OK',
      printer_status: 'IDLE',
      maintenance_mode: false,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    });

    if (
      config.supabase.url &&
      !config.supabase.url.includes('dummy') &&
      config.supabase.serviceRoleKey &&
      !config.supabase.serviceRoleKey.includes('dummy')
    ) {
      try {
        this.client = createClient(config.supabase.url, config.supabase.serviceRoleKey);
        this.isConnected = true;
        console.log('✅ Supabase connected successfully');
      } catch (err: any) {
        console.warn('⚠️ Supabase connection failed, using local resilient store:', err.message);
      }
    } else {
      console.log('ℹ️ Using resilient local in-memory DB + file store for simulation');
    }
  }

  public static getInstance(): SupabaseService {
    if (!SupabaseService.instance) {
      SupabaseService.instance = new SupabaseService();
    }
    return SupabaseService.instance;
  }

  // --- MACHINE OPERATIONS ---
  public async getMachine(id: string): Promise<Machine | null> {
    if (this.isConnected && this.client) {
      const { data, error } = await this.client.from('machines').select('*').eq('id', id).single();
      if (!error && data) return data as Machine;
    }
    return this.machines.get(id) || null;
  }

  public async getAllMachines(): Promise<Machine[]> {
    if (this.isConnected && this.client) {
      const { data, error } = await this.client.from('machines').select('*');
      if (!error && data) return data as Machine[];
    }
    return Array.from(this.machines.values());
  }

  public async updateMachineTelemetry(
    id: string,
    updates: Partial<Pick<Machine, 'paper_status' | 'ink_status' | 'printer_status' | 'status' | 'maintenance_mode'>>
  ): Promise<Machine> {
    const existing = await this.getMachine(id);
    const updated: Machine = {
      ...(existing || {
        id,
        location: 'Kiosk',
        status: 'ONLINE',
        mqtt_client_id: `client_${id}`,
        last_seen_at: new Date().toISOString(),
        paper_status: 'OK',
        ink_status: 'OK',
        printer_status: 'IDLE',
        maintenance_mode: false,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      }),
      ...updates,
      last_seen_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };

    if (this.isConnected && this.client) {
      await this.client.from('machines').upsert(updated);
    }
    this.machines.set(id, updated);
    this.recordMachineEvent(id, 'TELEMETRY', updates);
    return updated;
  }

  public recordMachineEvent(machine_id: string, event_type: string, payload: any): void {
    const event = {
      id: Math.random().toString(36).substring(2, 15),
      machine_id,
      event_type,
      payload,
      created_at: new Date().toISOString()
    };
    this.machineEvents.push(event);
    if (this.isConnected && this.client) {
      this.client.from('machine_events').insert(event).then();
    }
  }

  // --- JOB OPERATIONS ---
  public async getJob(id: string): Promise<Job | null> {
    if (this.isConnected && this.client) {
      const { data, error } = await this.client.from('jobs').select('*').eq('id', id).single();
      if (!error && data) return data as Job;
    }
    return this.jobs.get(id) || null;
  }

  public async getAllJobs(): Promise<Job[]> {
    if (this.isConnected && this.client) {
      const { data, error } = await this.client.from('jobs').select('*').order('created_at', { ascending: false });
      if (!error && data) return data as Job[];
    }
    return Array.from(this.jobs.values()).sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
  }

  public async saveJob(job: Job): Promise<Job> {
    job.updated_at = new Date().toISOString();
    if (this.isConnected && this.client) {
      await this.client.from('jobs').upsert(job);
    }
    this.jobs.set(job.id, job);
    return job;
  }

  public recordJobEvent(job_id: string, from_status: JobStatus | undefined, to_status: JobStatus, payload?: any): void {
    const event = {
      id: Math.random().toString(36).substring(2, 15),
      job_id,
      from_status,
      to_status,
      payload,
      created_at: new Date().toISOString()
    };
    this.jobEvents.push(event);
    if (this.isConnected && this.client) {
      this.client.from('job_events').insert(event).then();
    }
  }

  // --- FILE OPERATIONS ---
  public async getFile(id: string): Promise<FileRecord | null> {
    if (this.isConnected && this.client) {
      const { data, error } = await this.client.from('files').select('*').eq('id', id).single();
      if (!error && data) return data as FileRecord;
    }
    return this.files.get(id) || null;
  }

  public async saveFileRecord(file: FileRecord): Promise<FileRecord> {
    if (this.isConnected && this.client) {
      await this.client.from('files').upsert(file);
    }
    this.files.set(file.id, file);
    return file;
  }

  // --- PAYMENT OPERATIONS ---
  public async getPaymentByOrderId(orderId: string): Promise<Payment | null> {
    if (this.isConnected && this.client) {
      const { data, error } = await this.client.from('payments').select('*').eq('provider_order_id', orderId).single();
      if (!error && data) return data as Payment;
    }
    for (const p of this.payments.values()) {
      if (p.provider_order_id === orderId) return p;
    }
    return null;
  }

  public async getPaymentByWebhookEvent(eventId: string): Promise<Payment | null> {
    if (this.isConnected && this.client) {
      const { data, error } = await this.client.from('payments').select('*').eq('webhook_event_id', eventId).single();
      if (!error && data) return data as Payment;
    }
    for (const p of this.payments.values()) {
      if (p.webhook_event_id === eventId) return p;
    }
    return null;
  }

  public async savePayment(payment: Payment): Promise<Payment> {
    payment.updated_at = new Date().toISOString();
    if (this.isConnected && this.client) {
      await this.client.from('payments').upsert(payment);
    }
    this.payments.set(payment.id, payment);
    return payment;
  }
}
