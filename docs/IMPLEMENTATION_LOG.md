# Printora Implementation Log & Engineering Audit Trail

**Date:** 2026-09-06  
**Auditor & Implementer:** Principal Full-Stack & IoT Systems Engineer  
**Status:** All Deliverables Complete & Verified  

---

## 1. Timeline of Engineering Actions

### Phase 0: Codebase Inspection & Audit Report
- Cloned repo reviewed: `printora-backend/` (empty), `printora-kiosk-agent/` (legacy HTTP polling), `printora_frontend/` (Flutter with 11 empty stubs).
- Discovered and reported key framework contradiction (React Native specified vs. Flutter found).
- Published initial audit report at `docs/AUDIT_REPORT.md`.
- User confirmed decision to continue with Flutter app (`Option B`).

### Phase 1: Database & Schema Engineering (`database/`)
- Created `database/01_schema.sql` defining:
  - `machines`: hardware health, paper/ink telemetry, maintenance mode.
  - `jobs`: 10-state progression, amount, pages, copies, color, duplex, signed tokens.
  - `files`: storage path, converted PDF path, SHA-256 hash, page counts.
  - `payments`: Razorpay order/payment IDs, idempotency event ID, status.
  - `job_events` & `machine_events`: append-only audit trail.
  - Triggers for automatic `updated_at` timestamps.
- Created `database/02_seed.sql` to initialize `printer001` in online state.

### Phase 2: Production Backend Construction (`backend/`)
- Configured Express + TypeScript environment (`package.json`, `tsconfig.json`, `.env`).
- Implemented core services:
  - `SupabaseService`: Resilient dual-mode database (cloud Supabase + in-memory local fallback store).
  - `StateMachineService`: Strict state transition graph with transition guards.
  - `FileService`: Image-to-PDF conversion (using `pdf-lib`), PDF page counting, SHA-256 calculation, and short-lived signed JWT download tokens (300s expiry).
  - `PaymentService`: Razorpay sandbox order creator, HMAC SHA-256 webhook validator, idempotency guard.
  - `MqttService`: EMQX broker client publishing QoS 1 payloads (`jobId`, `downloadToken`, `checksum`, `downloadUrl`, settings).
  - `DeviceService`: Machine authentication, device JWT validation, progress reporting, post-print storage cleanup.
- Implemented API routers:
  - `mobile.routes.ts`: `GET /machines/:id/status`, `POST /jobs`, `POST /jobs/:id/upload`, `POST /jobs/:id/payment-session`, `GET /jobs/:id/status`.
  - `webhook.routes.ts`: `POST /webhooks/payment`.
  - `device.routes.ts`: `POST /device/auth`, `GET /device/jobs/pending`, `GET /device/jobs/:id/download`, `POST /device/jobs/:id/status`, `POST /device/machines/:id/heartbeat`.
  - `admin.routes.ts`: `GET /admin/machines`, `GET /admin/jobs`, `POST /admin/jobs/:id/refund`, `POST /admin/machines/:id/maintenance`.
- Created live web Admin Control Panel served at `GET /admin/dashboard`.
- Compiled TypeScript cleanly (`npm run build` -> Exit code 0).

### Phase 3: Hardware Simulation Architecture (`simulators/`)
- Developed Python 3.10 Raspberry Pi Agent (`simulators/pi-agent/agent.py`):
  - Connects to EMQX broker.
  - Authenticates with backend.
  - Subscribes to `machines/printer001/jobs/assigned`.
  - Downloads PDF via signed token over HTTPS.
  - Verifies SHA-256 cryptographic checksum.
  - Simulates physical print cycle (`DOWNLOADING` -> `READY_TO_PRINT` -> `PRINTING` -> `COMPLETED`).
  - Deposits final simulated output into `simulators/printed_jobs/`.
- Developed ESP32 Hardware State Controller (`simulators/esp32/simulator.py`):
  - Toggles Paper OK / Paper Out, Ink OK / Ink Low, Door Open / Door Closed, Temp Warning.
  - Publishes real-time telemetry to `machines/printer001/status`.
  - Supports interactive CLI and scripted headless CLI flags.

### Phase 4: Flutter Mobile Application Completion (`printora_frontend/`)
- Bootstrapped Flutter SDK (`Flutter 3.47.2 / Dart 3.13.2`).
- Resolved all 11 zero-byte files:
  - Created `KioskModel`, `PrintJobModel`, `UserModel`.
  - Implemented `ApiService`, `PaymentService`, `StorageService`, `AuthService`.
  - Built `LoadingWidget` and `PrimaryButton`.
  - Updated `UploadScreen` with machine readiness banners.
  - Enhanced `PrintSettingsScreen` with copies, color, duplex, dynamic pricing.
  - Added `PaymentPendingScreen` with Razorpay sandbox flow.
  - Created `OrderTrackingScreen` with 7-step live status progression.
  - Added demo quick-connect button in `QRScannerScreen` for testing without physical camera.
- Ran `flutter analyze` -> `No issues found! (ran in 7.4s)`.

### Phase 5: Automated End-to-End Simulation Testing (`tests/`)
- Created automated test harness `tests/simulate_e2e.py`.
- Ran full test suite covering Happy Path, Idempotency, Paper Out, Trust Boundary, and Admin Refund.
- 100% of tests passed with verified physical file outputs in `simulators/printed_jobs/`.
