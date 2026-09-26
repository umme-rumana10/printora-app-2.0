# Printora — Complete Setup Guide

## Architecture Overview

`
Flutter App (printora_frontend/)
     │ HTTP REST API
     ▼
Express Backend (printora-backend/)  ←──── Razorpay Webhook
     │ MQTT (QoS 1)          │ Supabase (jobs, files, machines, payments)
     ▼                        │
MQTT Broker (broker.emqx.io)  │
     │                        │
     ▼                        │
Pi-Agent Simulator (simulators/pi-agent/agent.py)
`

## Step 1: Connect Supabase

### 1.1 Get Your Credentials
1. Go to https://supabase.com/dashboard
2. Open your project → Settings → API
3. Copy: Project URL, anon public key, service_role key

### 1.2 Run the Migration SQL
1. Go to SQL Editor → New Query in Supabase Dashboard
2. Paste the entire contents of database/03_supabase_migration.sql
3. Click Run

### 1.3 Update .env

Open printora-backend/.env and set:
  SUPABASE_URL=https://YOUR-PROJECT-ID.supabase.co
  SUPABASE_ANON_KEY=your_anon_key
  SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

## Step 2: Configure Razorpay Sandbox

1. Login at https://dashboard.razorpay.com in Test Mode
2. Settings → API Keys → Generate Test Key
3. Settings → Webhooks → Add URL + copy secret
4. Update .env:
  RAZORPAY_KEY_ID=rzp_test_YOUR_KEY_ID
  RAZORPAY_KEY_SECRET=YOUR_KEY_SECRET
  RAZORPAY_WEBHOOK_SECRET=YOUR_WEBHOOK_SECRET

## Step 3: Run All Components

Start backend:
  cd printora-backend && npm run dev

Run Pi-Agent (separate terminal):
  pip install requests paho-mqtt
  python simulators/pi-agent/agent.py

Run E2E Tests:
  pip install requests reportlab
  python tests/simulate_e2e.py
