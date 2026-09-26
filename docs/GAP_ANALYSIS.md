# Printora Production Architecture Gap Analysis

**Project:** Printora Automated Printing Vending Machine  
**Target:** Single-Machine Production MVP (`printer001`), Multi-Machine Ready  
**Date:** 2026-09-06  

---

## 1. Executive Summary

This document contrasts the original repository state cloned from `https://github.com/umme-rumana10/printora-app` with the final implemented production-grade architecture.

---

## 2. Comprehensive Architectural Gap Matrix

| Architectural Domain | Original Repository State | Target Architecture Specification | Final Implemented State | Resolution Details |
| :--- | :--- | :--- | :--- | :--- |
| **Mobile Application** | Flutter app (`printora_frontend/`) with 11 empty 0-byte stubs, hardcoded LAN IP (`192.168.0.11:5000`), no duplex toggle, no live state machine tracking. | Full customer mobile flow: QR scan, status check, upload, copies, B&W / Color, duplex, dynamic price calculation, Razorpay checkout, live 10-state tracking. | Fully implemented & verified with Flutter 3.47 SDK (`No issues found`). | Completed all models, screens, and services. Added duplex toggle, dynamic pricing, and Razorpay sandbox flow. Cleaned all empty stubs and deprecated lints. |
| **Backend Architecture** | Empty folder (`printora-backend/`) with 0 files committed. | Modular NestJS/Node.js TypeScript API running on port 5000 with device auth, signed tokens, and admin routes. | High-performance Express + TypeScript modular backend in `backend/` and `printora-backend/`. | Built complete service layer (`SupabaseService`, `StateMachineService`, `FileService`, `PaymentService`, `MqttService`, `DeviceService`). |
| **Database & Schema** | No database migrations, schemas, or SQL scripts present. | Supabase PostgreSQL tables: `machines`, `jobs`, `files`, `payments`, `job_events`, `machine_events` with triggers & audit logs. | Production SQL migrations in `database/01_schema.sql` and seed data in `database/02_seed.sql`. | Created complete PostgreSQL schema with foreign keys, status check constraints, updated_at triggers, and `printer001` seed. |
| **Trust Model & Security** | Client directly commanded print operations; no HMAC verification. | Backend is single source of truth. Mobile app NEVER authorizes printing. Only verified Razorpay webhook triggers machine. | Strict trust model enforced via HMAC SHA-256 signature verification and short-lived signed tokens. | Reject any direct mobile print attempt. Webhook verification transitions `PAYMENT_PENDING` -> `PAID` -> `ASSIGNED_TO_MACHINE`. |
| **IoT & Transport** | Legacy polling loop via `setInterval` calling `GET /api/print/jobs/queued` in `printora-kiosk-agent`. | MQTT over EMQX Cloud (QoS 1). MQTT carries metadata and tokens only; NO files over MQTT. | EMQX MQTT integration on `machines/printer001/jobs/assigned`, `machines/printer001/status`, `machines/printer001/heartbeat`. | Implemented QoS 1 MQTT client in backend and Python simulator. Files served exclusively via HTTPS short-lived signed URLs. |
| **Hardware Simulation** | Node.js script sending files to local Windows print spooler via `pdf-to-printer`. | Isolated Python Raspberry Pi agent and ESP32 hardware state simulator without physical hardware requirements. | Python 3.10 Raspberry Pi agent (`simulators/pi-agent/agent.py`) and ESP32 state controller (`simulators/esp32/simulator.py`). | Full simulation with configurable delays (2s download, 8s print), SHA-256 verification, and mock print delivery to `simulators/printed_jobs/`. |
| **Admin Operations** | Kiosk dashboard misplaced inside customer mobile app. | Web admin dashboard displaying machine online status, paper, ink, current jobs, history, maintenance toggle, and refunds. | Web Control Panel served at `http://localhost:5000/admin/dashboard` with live fleet telemetry and one-click refunds. | Built interactive responsive dashboard into backend, along with REST endpoints `GET /admin/machines`, `GET /admin/jobs`, `POST /admin/jobs/:id/refund`. |

---

## 3. Job State Machine Comparison

```
SPECIFIED STATE MACHINE:
CREATED ➔ UPLOADED ➔ AWAITING_PAYMENT ➔ PAYMENT_PENDING ➔ PAID ➔ ASSIGNED_TO_MACHINE ➔ DOWNLOADING ➔ READY_TO_PRINT ➔ PRINTING ➔ COMPLETED
                                                                                               (Terminals: FAILED, CANCELLED, EXPIRED, REFUNDED)

ORIGINAL REPO BEHAVIOR:
QUEUED ➔ PRINTING ➔ READY_FOR_PICKUP (Fragmented, non-standard, no payment gating)

FINAL IMPLEMENTED BEHAVIOR:
Strictly matches the 10-state machine specification in `backend/src/services/state-machine.service.ts` and visualized in `printora_frontend/lib/screens/order_tracking/order_tracking_screen.dart`.
```

---

## 4. Conclusion

All identified architectural and functional gaps have been fully remediated. The system now functions as a unified, test-verified, production-style vending machine MVP.
