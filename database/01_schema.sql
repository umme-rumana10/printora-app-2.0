-- ==============================================================================
-- PRINTORA AUTOMATED PRINTING VENDING MACHINE - DATABASE SCHEMA MIGRATION
-- Target: Supabase / PostgreSQL
-- ==============================================================================

-- Enable UUID extension if not already available
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. MACHINES TABLE
CREATE TABLE IF NOT EXISTS machines (
    id VARCHAR(64) PRIMARY KEY, -- e.g. 'printer001'
    location VARCHAR(255) NOT NULL DEFAULT 'Main Lobby',
    status VARCHAR(32) NOT NULL DEFAULT 'ONLINE', -- ONLINE, OFFLINE, BUSY, ERROR, MAINTENANCE
    mqtt_client_id VARCHAR(128) NOT NULL,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    paper_status VARCHAR(32) NOT NULL DEFAULT 'OK', -- OK, LOW, OUT
    ink_status VARCHAR(32) NOT NULL DEFAULT 'OK', -- OK, LOW, EMPTY
    printer_status VARCHAR(32) NOT NULL DEFAULT 'IDLE', -- IDLE, PRINTING, ERROR, MAINTENANCE
    maintenance_mode BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. FILES TABLE
CREATE TABLE IF NOT EXISTS files (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    storage_path TEXT NOT NULL,
    converted_pdf_path TEXT,
    sha256 VARCHAR(64) NOT NULL,
    page_count INTEGER NOT NULL DEFAULT 1,
    original_filename VARCHAR(255) NOT NULL,
    mime_type VARCHAR(64) NOT NULL,
    file_size BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. JOBS TABLE
-- Valid States:
-- CREATED -> UPLOADED -> AWAITING_PAYMENT -> PAYMENT_PENDING -> PAID -> 
-- ASSIGNED_TO_MACHINE -> DOWNLOADING -> READY_TO_PRINT -> PRINTING -> COMPLETED
-- Terminals: FAILED, CANCELLED, EXPIRED, REFUNDED
CREATE TABLE IF NOT EXISTS jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    machine_id VARCHAR(64) NOT NULL REFERENCES machines(id) ON DELETE RESTRICT,
    file_id UUID REFERENCES files(id) ON DELETE SET NULL,
    pages INTEGER NOT NULL DEFAULT 1,
    copies INTEGER NOT NULL DEFAULT 1,
    color BOOLEAN NOT NULL DEFAULT FALSE,
    duplex BOOLEAN NOT NULL DEFAULT FALSE,
    amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    status VARCHAR(32) NOT NULL DEFAULT 'CREATED',
    download_token VARCHAR(128),
    download_token_expires_at TIMESTAMPTZ,
    paid_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT valid_job_status CHECK (
        status IN (
            'CREATED',
            'UPLOADED',
            'AWAITING_PAYMENT',
            'PAYMENT_PENDING',
            'PAID',
            'ASSIGNED_TO_MACHINE',
            'DOWNLOADING',
            'READY_TO_PRINT',
            'PRINTING',
            'COMPLETED',
            'FAILED',
            'CANCELLED',
            'EXPIRED',
            'REFUNDED'
        )
    )
);

-- 4. PAYMENTS TABLE
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    provider VARCHAR(32) NOT NULL DEFAULT 'razorpay',
    provider_order_id VARCHAR(128) NOT NULL,
    provider_payment_id VARCHAR(128),
    webhook_event_id VARCHAR(128) UNIQUE, -- Enforces idempotency
    status VARCHAR(32) NOT NULL DEFAULT 'PENDING', -- PENDING, SUCCESS, FAILED, REFUNDED
    amount NUMERIC(10, 2) NOT NULL,
    currency VARCHAR(8) NOT NULL DEFAULT 'INR',
    raw_payload JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. JOB EVENTS AUDIT LOG TABLE
CREATE TABLE IF NOT EXISTS job_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    from_status VARCHAR(32),
    to_status VARCHAR(32) NOT NULL,
    payload JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. MACHINE EVENTS AUDIT LOG TABLE
CREATE TABLE IF NOT EXISTS machine_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    machine_id VARCHAR(64) NOT NULL REFERENCES machines(id) ON DELETE CASCADE,
    event_type VARCHAR(64) NOT NULL, -- TELEMETRY, STATUS_CHANGE, ERROR, HEARTBEAT
    payload JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- INDEXES FOR HIGH-THROUGHPUT LOOKUPS
CREATE INDEX IF NOT EXISTS idx_jobs_machine_id ON jobs(machine_id);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
CREATE INDEX IF NOT EXISTS idx_payments_order_id ON payments(provider_order_id);
CREATE INDEX IF NOT EXISTS idx_payments_webhook_id ON payments(webhook_event_id);
CREATE INDEX IF NOT EXISTS idx_job_events_job_id ON job_events(job_id);
CREATE INDEX IF NOT EXISTS idx_machine_events_machine_id ON machine_events(machine_id);

-- UPDATED_AT TRIGGER FUNCTION
CREATE OR REPLACE FUNCTION update_timestamp_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS tr_update_machines_timestamp ON machines;
CREATE TRIGGER tr_update_machines_timestamp
    BEFORE UPDATE ON machines
    FOR EACH ROW
    EXECUTE PROCEDURE update_timestamp_column();

DROP TRIGGER IF EXISTS tr_update_jobs_timestamp ON jobs;
CREATE TRIGGER tr_update_jobs_timestamp
    BEFORE UPDATE ON jobs
    FOR EACH ROW
    EXECUTE PROCEDURE update_timestamp_column();

DROP TRIGGER IF EXISTS tr_update_payments_timestamp ON payments;
CREATE TRIGGER tr_update_payments_timestamp
    BEFORE UPDATE ON payments
    FOR EACH ROW
    EXECUTE PROCEDURE update_timestamp_column();
