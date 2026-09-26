# Printora Codebase Audit & Architectural Assessment Report

**Date:** 2026-09-06  
**Auditor:** Principal Full-Stack & IoT Systems Engineer  
**Repository:** `https://github.com/umme-rumana10/printora-app`  
**Target Architecture:** Automated Printing Vending Machine Production MVP (Single Machine `printer001`, scalable to multi-tenant)

---

## 1. Executive Summary

A comprehensive audit was performed on the cloned local repository (`printora-app`). The repository was intended to house a full-stack printing kiosk ecosystem. However, our inspection revealed significant architectural divergence, missing components, empty directories, and a primary technology conflict between the user requirements and the existing repository contents:

1. **Frontend Tech Stack Conflict:** The repository contains a **Flutter (Dart)** application under `printora_frontend/`, whereas the specification requests continuing an existing **React Native** application. Furthermore, the local machine has **Node.js (v22.17.1)** and **Python (3.10.0)** installed, but **Flutter is NOT installed**.
2. **Backend Absent:** The `printora-backend/` directory is completely empty (0 files committed).
3. **Kiosk Agent Misalignment:** `printora-kiosk-agent/` contains an HTTP-polling prototype using `axios` and `pdf-to-printer` targeting a non-existent local server (`192.168.0.11:5000`). It does not use MQTT, does not perform SHA-256 verification, and does not follow the required secure signed-URL trust model.
4. **Database & Cloud Integrations Missing:** There are no Supabase migrations, no database schemas, no Razorpay SDK integrations, and no MQTT broker setups.

This audit details the exact status of the repository, catalogues existing vs. missing capabilities, identifies dead and duplicate code, and presents an actionable path forward.

---

## 2. Technology Detection & Environment Audit

| Component | Expected in Spec | Found in Repository | Local Host Environment | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Mobile App** | React Native (TypeScript) | Flutter (Dart `3.3.0 < 4.0.0`) | Flutter CLI: **Not Found**; Node.js: **v22.17.1** | **Conflict** |
| **Backend** | NestJS / Node (TypeScript) | `printora-backend/` (Empty directory) | Node.js: **v22.17.1**, npm: **10.9.2** | **Missing** |
| **Database** | Supabase (PostgreSQL + Storage) | None | N/A | **Missing** |
| **Payment Gateway** | Razorpay Sandbox + Webhook | Empty file `payment_service.dart` | N/A | **Missing** |
| **IoT Transport** | MQTT (EMQX Cloud, QoS 1) | Polling via HTTP `setInterval` | Python: **3.10.0** (Ready for Simulators) | **Incorrect** |
| **Simulators** | Python Pi Agent & ESP32 State | Windows shell printing `pdf-to-printer` | Python: **3.10.0** | **Missing** |

---

## 3. Directory-by-Directory Audit

### 3.1. `printora-backend/`
- **Status:** Empty directory.
- **Files:** 0 files.
- **Analysis:** No backend framework, routes, models, or configurations were committed to the repository.

### 3.2. `printora-kiosk-agent/`
- **Status:** Partially implemented legacy prototype (Node.js CommonJS).
- **Dependencies:** `axios` (^1.18.1), `dotenv` (^17.4.2), `pdf-to-printer` (^5.8.0).
- **Files & Roles:**
  - `controller.js`: Runs an infinite polling loop using `setInterval(..., Number(process.env.POLL_INTERVAL))`.
  - `scheduler/printerScheduler.js`: Checks `/api/print/jobs/queued`, downloads file via `downloadService.js`, and prints using `pdf-to-printer`.
  - `services/apiService.js`: Hardcodes calls to `BACKEND_URL/api/print/jobs/...`.
  - `services/downloadService.js`: Streams files from unauthenticated HTTP URL directly to disk.
  - `services/printerService.js`: Calls Windows system print command (`pdf-to-printer`).
  - `services/fileService.js`: Deletes downloaded files with `fs.unlinkSync`.
- **Architectural Defects:**
  - Violates the trust model: Kiosk polls HTTP directly instead of subscribing to secure MQTT job assignment topics.
  - No SHA-256 verification before printing.
  - Relies on physical printer drivers via Windows command line rather than an isolated simulation pipeline.

### 3.3. `printora_frontend/`
- **Status:** Flutter project. Contains 13 Dart files and 11 empty/zero-byte placeholders.
- **Dependencies (`pubspec.yaml`):** `flutter`, `cupertino_icons`, `mobile_scanner` (^7.1.2), `file_selector` (^1.0.3), `dio` (^5.7.0), `file_picker` (^10.3.2).
- **Active Code Review:**
  - `lib/main.dart`: Standard Flutter entry point launching `HomeScreen`.
  - `lib/screens/home/home_screen.dart`: UI with "Scan QR Code" and "Select Kiosk" buttons.
  - `lib/screens/qr/qr_scanner_screen.dart`: Scans camera stream for QR format `PRINTORA:KIOSK_ID:<kioskId>` and navigates to `UploadScreen`.
  - `lib/screens/upload/upload_screen.dart`: Picks documents (`pdf`, `jpg`, `jpeg`, `png`) via `file_selector`. Displays list of selected files.
  - `lib/screens/print_settings/print_settings_screen.dart`: Configures copies, color vs. B&W toggle, page range. Calculates local estimated cost (B&W = ₹2/copy, Color = ₹10/copy). Sends multipart `FormData` to `ApiService().uploadMultipleFiles()`.
  - `lib/order/order_submitted_screen.dart`: Static receipt screen with Order ID and price.
  - `lib/screens/order_tracking/order_tracking_screen.dart`: Polls `GET /api/print/order/:id` every 5 seconds.
  - `lib/screens/kiosk/kiosk_dashboard_screen.dart`: Operator view to manually trigger `startPrinting` and `completePrinting`.
  - `lib/screens/kiosk/kiosk_selection_screen.dart`: Stub screen ("Kiosk List Coming Soon").
  - `lib/models/print_option.dart`: Data class for print preferences.
  - `lib/state/app_state.dart`: Static class holding only `kioskId`.

---

## 4. Feature Gap Analysis

### 4.1. Completed Features
- [x] Home screen UI design & basic layout.
- [x] QR code scanning and kiosk ID parsing (`PRINTORA:KIOSK_ID:<id>`).
- [x] Local file picker supporting PDF, JPG, and PNG.
- [x] Print options selector (copies, color/B&W toggle, page range input).
- [x] Basic client-side cost formula (₹2 B&W / ₹10 Color).
- [x] Kiosk agent file download and post-print cleanup logic.

### 4.2. Partially Completed Features
- [ ] **Upload Flow:** Files are packaged into a single multipart request to `POST /api/print/upload-multiple` targeting a local LAN IP (`192.168.0.11:5000`). Does not generate SHA-256, does not upload to Supabase Storage, and does not validate pages against backend quotas.
- [ ] **Job Tracking:** `OrderTrackingScreen` polls `GET /api/print/order/:id` every 5s with simplistic status aggregation (`QUEUED`, `PRINTING`, `READY FOR PICKUP`), rather than the required 10-state machine.
- [ ] **Kiosk Execution:** Kiosk agent downloads and invokes local OS printer, but lacks auth tokens, heartbeat telemetry, and MQTT event subscription.

### 4.3. Missing Features (Must Be Built)
- [ ] **Backend Service:** Complete NestJS/Node server with all required endpoints:
  - `GET /machines/:id/status`
  - `POST /jobs`
  - `POST /jobs/:id/upload`
  - `POST /jobs/:id/payment-session`
  - `GET /jobs/:id/status`
  - `POST /webhooks/payment` (Razorpay signature verified & idempotent)
  - `POST /device/auth`
  - `GET /device/jobs/pending`
  - `GET /device/jobs/:id/download` (Short-lived signed URL, 2–5 min expiry)
  - `POST /device/jobs/:id/status`
  - `POST /device/machines/:id/heartbeat`
  - `GET /admin/machines`
  - `GET /admin/jobs`
  - `POST /admin/jobs/:id/refund`
- [ ] **Database & Supabase Storage:**
  - Tables: `machines`, `jobs`, `files`, `payments`, `job_events`, `machine_events`.
  - Row Level Security (RLS) & triggers for updated timestamps.
  - Private Supabase Storage bucket for raw and converted PDFs.
- [ ] **Strict Job State Machine:**
  - `CREATED` → `UPLOADED` → `AWAITING_PAYMENT` → `PAYMENT_PENDING` → `PAID` → `ASSIGNED_TO_MACHINE` → `DOWNLOADING` → `READY_TO_PRINT` → `PRINTING` → `COMPLETED`
  - Transition guards for `FAILED`, `CANCELLED`, `EXPIRED`, `REFUNDED`.
- [ ] **Razorpay Sandbox Integration:**
  - Order generation on backend.
  - Mobile checkout session initialization.
  - HMAC SHA-256 signature verification on backend webhook.
  - Mobile app strictly prohibited from authorizing printing directly.
- [ ] **File Processing Pipeline:**
  - Image to PDF conversion (JPG, PNG → PDF).
  - Accurate PDF page counting.
  - Cryptographic SHA-256 hash calculation for download integrity.
- [ ] **MQTT IoT Layer (EMQX):**
  - Topic structure:
    - `machines/printer001/jobs/assigned` (QoS 1 payload: `jobId`, `downloadToken`, `checksum`, print settings)
    - `machines/printer001/status` (telemetry: paper, ink, temperature, door)
    - `machines/printer001/heartbeat` (online/offline tracking)
- [ ] **Simulated Hardware Pipeline:**
  - `simulators/pi-agent/` (Python): Authenticates as `printer001`, listens on MQTT, downloads signed URL, checks SHA-256, transitions through statuses with configurable delays (2s download, 8s print), saves completed PDFs to `simulators/printed_jobs/`.
  - `simulators/esp32/` (Python/Node): Interactive or headless sensor state simulator (Paper OK / Paper Out, Ink Low, Door Open, Temperature Warning).
- [ ] **Admin Dashboard:**
  - Real-time machine monitoring, inventory status, active job tracking, and refund triggers.

---

## 5. Dead Code & Zero-Byte Files

The following 11 files in `printora_frontend` are completely empty (0 bytes) and need either implementation or cleanup:

1. `printora_frontend/lib/services/payment_service.dart` (0 bytes)
2. `printora_frontend/lib/services/storage_service.dart` (0 bytes)
3. `printora_frontend/lib/services/auth_service.dart` (0 bytes)
4. `printora_frontend/lib/models/kiosk_model.dart` (0 bytes)
5. `printora_frontend/lib/models/print_job_model.dart` (0 bytes)
6. `printora_frontend/lib/models/user_model.dart` (0 bytes)
7. `printora_frontend/lib/screens/auth/login_screen.dart` (0 bytes)
8. `printora_frontend/lib/screens/auth/register_screen.dart` (0 bytes)
9. `printora_frontend/lib/screens/tracking/tracking_screen.dart` (0 bytes)
10. `printora_frontend/lib/widgets/loading_widget.dart` (0 bytes)
11. `printora_frontend/lib/widgets/primary_button.dart` (0 bytes)

---

## 6. Duplicate & Conflicting Code

1. **Duplicate Tracking Screens:**
   - `lib/screens/order_tracking/order_tracking_screen.dart` (implemented) vs. `lib/screens/tracking/tracking_screen.dart` (0 bytes).
2. **Kiosk Selection vs. QR Scanner:**
   - The app has two parallel entry routes: `QRScannerScreen` and `KioskSelectionScreen` (which is a stub). The target architecture specifies QR code scan as the primary flow.
3. **Kiosk Dashboard inside Customer App:**
   - `lib/screens/kiosk/kiosk_dashboard_screen.dart` was placed inside the customer-facing mobile app rather than in an admin or operator portal.

---

## 7. Major Architectural Contradiction for User Decision

> [!IMPORTANT]
> **Key Decision: Frontend Framework (React Native vs. Flutter)**
> - **The Prompt States:** "Continue an existing React Native app instead of rebuilding it. My local repository is already cloned from: https://github.com/umme-rumana10/printora-app" and "PROJECT STRUCTURE: backend/, mobile/, simulators/..."
> - **The Reality:** The cloned repository contains a **Flutter** app (`printora_frontend/`), NOT React Native.
> - **The Host Machine:** Node.js (v22.17) and Python (3.10) are installed. **Flutter CLI is NOT installed** on this Windows environment.
> - **Option A (Recommended):** Build the `mobile/` app using **React Native (Expo / React Native TypeScript)** as explicitly requested in the architectural specification. This natively uses the existing Node.js environment, matches the requested `mobile/` directory structure, easily integrates Razorpay and Supabase SDKs, and can be verified directly.
> - **Option B:** Keep the Flutter app in `printora_frontend/`, which requires installing the Flutter SDK, Android SDK/command-line tools, and building the missing services in Dart.

---

## 8. Recommended Phased Implementation Plan

Once the user confirms the framework decision:

### Phase 1: Database & Supabase Layer (`database/`)
1. Create PostgreSQL migration scripts defining `machines`, `jobs`, `files`, `payments`, `job_events`, `machine_events`.
2. Configure Supabase storage bucket policies for secure, signed URL retrieval.
3. Seed initial machine record for `printer001`.

### Phase 2: Backend Architecture (`backend/`)
1. Initialize Node.js/TypeScript backend (NestJS/Fastify/Express) in `backend/`.
2. Implement core modules:
   - `Auth & DeviceModule`: Machine JWT authentication and heartbeat.
   - `JobsModule`: Complete 10-state machine orchestrator.
   - `FilesModule`: Image-to-PDF conversion, PDF page counting, SHA-256 calculation, and short-lived signed URL generation.
   - `PaymentsModule`: Razorpay order creation and HMAC webhook verification.
   - `MqttModule`: EMQX client publishing QoS 1 job assignment payloads.
   - `AdminModule`: Fleet overview, job history, and refunds.

### Phase 3: Hardware Simulators (`simulators/`)
1. **`simulators/pi-agent/` (Python 3.10):**
   - Connect to EMQX MQTT broker on `machines/printer001/jobs/assigned`.
   - Download file using short-lived signed URL.
   - Verify SHA-256 hash.
   - Emulate physical print sequence with delays (`DOWNLOADING` → `READY_TO_PRINT` → `PRINTING` → `COMPLETED`).
   - Save finalized output into `simulators/printed_jobs/`.
   - Report progress back to backend over MQTT / HTTPS.
2. **`simulators/esp32/` (Python 3.10):**
   - Publish hardware state telemetry (Paper OK, Paper Out, Ink Low, Door Open, Temp) to `machines/printer001/status`.
   - Provide interactive CLI / test hooks to simulate error states (Paper Out, Door Open).

### Phase 4: Mobile Application (`mobile/`)
1. Implement the complete flow matching the target UX:
   - QR Machine scanner / manual input (`printer001`).
   - Machine telemetry & readiness check (`GET /machines/printer001/status`).
   - Document picker & multi-format support (PDF, JPG, PNG).
   - Print configuration (Copies, B&W / Color toggle, Duplex toggle).
   - Dynamic price calculation based on verified page count.
   - Razorpay Sandbox payment checkout.
   - Payment pending & live job tracking screen (real-time state transitions).

### Phase 5: Verification & End-to-End Simulation
1. Run automated end-to-end happy path test (`printer001` → upload → payment → webhook → MQTT → Pi download → mock print → `COMPLETED`).
2. Run edge & failure scenarios: Paper Out, MQTT disconnect, checksum mismatch, duplicate webhook.
3. Produce all required documentation artifacts:
   - `docs/GAP_ANALYSIS.md`
   - `docs/IMPLEMENTATION_LOG.md`
   - `docs/SIMULATION_RESULTS.md`
   - `docs/RUN_INSTRUCTIONS.md`
