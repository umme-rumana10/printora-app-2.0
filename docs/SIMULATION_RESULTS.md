# Printora End-to-End Simulation & Verification Results

**Date:** 2026-09-06  
**Test Suite:** `tests/simulate_e2e.py`  
**Target Environment:** Local Full-Stack + Software IoT Hardware Simulators  
**Machine Under Test:** `printer001`  
**Overall Status:** **100% PASSED (6 / 6 Test Suites)**

---

## 1. Test Execution Summary

```
=================================================================
🚀 STARTING FULL PRINTORA END-TO-END AUTOMATED VERIFICATION
=================================================================

[SETUP] Created sample 3-page PDF at: tests/sample_doc.pdf

[TEST 1] Machine printer001 is ONLINE and READY. (Paper: OK)

[TEST 2] --- Starting Happy Path Flow ---
[STEP 1] Job created: 709e9cf6-6c8c-47ed-b74f-d8e0062ce9a2 (Status: CREATED)
[STEP 2] File uploaded and analyzed. Pages: 3, SHA-256: 5cb74b64b470..., Amount: ₹12 (Status: UPLOADED)
[STEP 3] Razorpay Sandbox order created: order_hbx2jayymf
[STEP 3b] Job state verified: PAYMENT_PENDING
[STEP 4] Razorpay Webhook verified. Job assigned to machine. (Status: ASSIGNED_TO_MACHINE)
[STEP 5] Pi Agent transitioning state -> DOWNLOADING
[STEP 6] PDF downloaded over HTTPS. SHA-256 integrity verified: 5cb74b64b470025e... OK
[STEP 7] Pi Agent transitioning state -> READY_TO_PRINT
[STEP 8] Pi Agent transitioning state -> PRINTING
[STEP 9] Simulated printer deposited output to: simulators/printed_jobs/test_printed_709e9cf6-6c8c-47ed-b74f-d8e0062ce9a2.pdf
[STEP 10] Pi Agent transitioning state -> COMPLETED
[RESULT] Job 709e9cf6-6c8c-47ed-b74f-d8e0062ce9a2 reaches COMPLETED in mobile tracking! Happy path test succeeded.

[TEST 3] --- Testing Duplicate Webhook Idempotency ---
[TEST 3] Duplicate webhook was safely ignored. Idempotency check PASSED.

[TEST 4] --- Testing Hardware Telemetry (Paper Out) Guard ---
[TEST 4] Job creation correctly rejected with message: Machine is currently unavailable for printing
[TEST 4] Machine restored to Paper OK. Telemetry guard test PASSED.

[TEST 5] --- Testing Trust Boundary & Unauthorized Print Guard ---
[TEST 5] Direct print attempt without verified payment was blocked. Trust boundary PASSED.

[TEST 6] --- Testing Admin Refund ---
[TEST 6] Job 709e9cf6-6c8c-47ed-b74f-d8e0062ce9a2 successfully marked REFUNDED. Admin refund PASSED.

=================================================================
📊 FINAL VERIFICATION SUMMARY:
=================================================================
  • Machine_Ready                      : PASSED
  • Happy_Path_Flow                    : PASSED
  • Duplicate_Webhook_Idempotency      : PASSED
  • Paper_Out_Guard                    : PASSED
  • Trust_Boundary_Guard               : PASSED
  • Admin_Refund                       : PASSED
=================================================================
🏆 ALL 6 TEST SUITES PASSED FLAWLESSLY!
```

---

## 2. Test Details & Assertions Verified

### Test 1: Machine Readiness Telemetry
- **API Queried:** `GET /machines/printer001/status`
- **Assertion:** `canAcceptJobs == true`, `paper_status == "OK"`, `status == "ONLINE"`.
- **Result:** Machine verified online and available.

### Test 2: Full Happy Path Execution
- **Step 1:** `POST /jobs` creates job record with `copies=2`, `color=false`, `duplex=false` in state `CREATED`.
- **Step 2:** `POST /jobs/:id/upload` streams 3-page PDF. Backend inspects pages (`page_count = 3`), computes cryptographic SHA-256 (`5cb74b64b470025e...`), calculates total amount (`3 pages * 2 copies * ₹2 = ₹12.00`), and transitions to `UPLOADED`.
- **Step 3:** `POST /jobs/:id/payment-session` creates Razorpay Sandbox order (`order_hbx2jayymf`) and transitions job to `PAYMENT_PENDING`.
- **Step 4:** `POST /webhooks/payment` sends HMAC-signed payload (`x-razorpay-signature`). Backend verifies signature, updates payment status to `SUCCESS`, transitions job to `PAID`, generates short-lived signed download token (300s expiry), transitions job to `ASSIGNED_TO_MACHINE`, and publishes MQTT job assignment (QoS 1).
- **Step 5–10:** Pi simulator receives assignment, transitions to `DOWNLOADING`, streams file over HTTPS using signed token, computes SHA-256 and verifies exact match, transitions to `READY_TO_PRINT`, transitions to `PRINTING`, copies file to `simulators/printed_jobs/test_printed_709e9cf6-6c8c-47ed-b74f-d8e0062ce9a2.pdf`, transitions to `COMPLETED`.
- **Result:** Mobile tracking queries `GET /jobs/:id/status` and confirms final status is `COMPLETED` with `completed_at` timestamp.

### Test 3: Duplicate Webhook Idempotency
- **Scenario:** The exact same Razorpay webhook event is re-delivered.
- **Assertion:** Backend checks `webhook_event_id` in `payments` table, detects duplication, logs idempotent ignore, and returns HTTP 200 without attempting invalid state re-transition or duplicate printing.
- **Result:** Duplicate safely ignored.

### Test 4: Hardware Error (Paper Out) Guard
- **Scenario:** ESP32 simulator reports `paper_status = "OUT"`.
- **Assertion:** `GET /machines/printer001/status` returns `canAcceptJobs = false`. `POST /jobs` is rejected with HTTP 400 (`Machine is currently unavailable for printing`).
- **Recovery:** ESP32 restores paper to `OK`. Job creation succeeds again.
- **Result:** Hardware safety interlock verified.

### Test 5: Trust Boundary & Unauthorized Print Guard
- **Scenario:** Client attempts to call device status endpoint directly to transition an unpaid job to `PRINTING` without a valid webhook.
- **Assertion:** Backend rejects request with HTTP 401/403 due to missing device credentials and invalid state transition.
- **Result:** Trust boundary strictly protected.

### Test 6: Admin Dashboard Refund
- **Scenario:** Admin calls `POST /admin/jobs/:id/refund` on completed job.
- **Assertion:** Job transitions to `REFUNDED`. Audit event logged in `job_events`.
- **Result:** Refund successfully processed and reflected in tracking.

---

## 3. Physical Artifact Verification

The mock printer successfully saved the printed document:
```
Directory: simulators/printed_jobs/
  - test_printed_709e9cf6-6c8c-47ed-b74f-d8e0062ce9a2.pdf (2,872 bytes)
```
Inspection confirms valid PDF structure matching the generated sample document.
