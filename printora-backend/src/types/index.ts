export type JobStatus =
  | 'CREATED'
  | 'UPLOADED'
  | 'AWAITING_PAYMENT'
  | 'PAYMENT_PENDING'
  | 'PAID'
  | 'ASSIGNED_TO_MACHINE'
  | 'DOWNLOADING'
  | 'READY_TO_PRINT'
  | 'PRINTING'
  | 'COMPLETED'
  | 'FAILED'
  | 'CANCELLED'
  | 'EXPIRED'
  | 'REFUNDED';

export type MachineStatus = 'ONLINE' | 'OFFLINE' | 'BUSY' | 'ERROR' | 'MAINTENANCE';
export type PaperStatus = 'OK' | 'LOW' | 'OUT';
export type InkStatus = 'OK' | 'LOW' | 'EMPTY';
export type PrinterStatus = 'IDLE' | 'PRINTING' | 'ERROR' | 'MAINTENANCE';

export interface Machine {
  id: string;
  location: string;
  status: MachineStatus;
  mqtt_client_id: string;
  last_seen_at: string;
  paper_status: PaperStatus;
  ink_status: InkStatus;
  printer_status: PrinterStatus;
  maintenance_mode: boolean;
  created_at: string;
  updated_at: string;
}

export interface FileRecord {
  id: string;
  storage_path: string;
  converted_pdf_path?: string;
  sha256: string;
  page_count: number;
  original_filename: string;
  mime_type: string;
  file_size: number;
  created_at: string;
}

export interface Job {
  id: string;
  machine_id: string;
  file_id?: string;
  pages: number;
  copies: number;
  color: boolean;
  duplex: boolean;
  amount: number;
  status: JobStatus;
  download_token?: string;
  download_token_expires_at?: string;
  paid_at?: string;
  completed_at?: string;
  created_at: string;
  updated_at: string;
}

export interface Payment {
  id: string;
  job_id: string;
  provider: string;
  provider_order_id: string;
  provider_payment_id?: string;
  webhook_event_id?: string;
  status: 'PENDING' | 'SUCCESS' | 'FAILED' | 'REFUNDED';
  amount: number;
  currency: string;
  raw_payload?: any;
  created_at: string;
  updated_at: string;
}

export interface MqttJobAssignedPayload {
  jobId: string;
  downloadUrl: string;
  downloadToken: string;
  checksum: string; // SHA-256
  settings: {
    pages: number;
    copies: number;
    color: boolean;
    duplex: boolean;
  };
}

export interface MachineTelemetryPayload {
  paper_status?: PaperStatus;
  ink_status?: InkStatus;
  printer_status?: PrinterStatus;
  door_status?: 'CLOSED' | 'OPEN';
  temperature_celsius?: number;
  warning?: string;
}
