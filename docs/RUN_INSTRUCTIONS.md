# Printora Run & Operational Instructions

This guide provides exact commands and procedures to run each component of the Printora Automated Printing Vending Machine ecosystem.

---

## 1. Quick Start: Running the Full Ecosystem

### Terminal 1: Backend Server
```bash
cd backend
npm install
npm run build
npm start
```
- **Port:** `http://localhost:5000`
- **Health Check:** `http://localhost:5000/health`
- **Admin Control Panel:** `http://localhost:5000/admin/dashboard`

---

### Terminal 2: Simulated Raspberry Pi Agent (Printer `printer001`)
```bash
# Python 3.10+
python simulators/pi-agent/agent.py
```
- **Function:** Listens for MQTT job assignments on `machines/printer001/jobs/assigned`, downloads PDF via signed URL over HTTPS, verifies SHA-256, and simulates hardware printing (2s download, 8s print).
- **Physical Output:** Completed jobs are saved to `simulators/printed_jobs/`.

---

### Terminal 3: Simulated ESP32 Hardware State Controller
```bash
# Interactive Mode (allows toggling Paper Out, Ink Low, Door Open, Temp Warning)
python simulators/esp32/simulator.py --interactive

# Headless / Scripted Mode
python simulators/esp32/simulator.py --set-paper OUT
python simulators/esp32/simulator.py --set-paper OK
```

---

### Terminal 4: Flutter Mobile App
```bash
cd printora_frontend
# Run on Chrome/Web
flutter run -d chrome

# Run on connected Windows desktop
flutter run -d windows

# Run on connected Android device / emulator
flutter run -d android
```

---

## 2. Automated End-to-End Test Suite

Run the full automated test suite that tests the entire flow from job creation, upload, Razorpay webhook, MQTT dispatch, Pi download, SHA-256 verification, mock print, and failure tests:

```bash
python tests/simulate_e2e.py
```

---

## 3. Sample QR Code & Connecting to Machine

The mobile app includes camera QR scanning and an instant demo shortcut:

### Text Encoded in Physical QR Code:
```
PRINTORA:KIOSK_ID:printer001
```

### Displaying / Printing Sample QR Code:
You can generate a test QR code online (or via `qrencode`):
```
Text: PRINTORA:KIOSK_ID:printer001
```
Or in the mobile app, navigate to **Scan QR Code** and tap the **"Quick Demo: Connect to printer001"** button.

---

## 4. Sample Test Accounts & Credentials

### Machine Credentials
| Machine ID | Location | Secret Key | Status |
| :--- | :--- | :--- | :--- |
| `printer001` | Tech Hub Center - Main Lobby Kiosk | `printer001_secret` | ONLINE |

### Razorpay Sandbox Test Credentials
- **Key ID:** `rzp_test_dummy_key_id` (or your live sandbox key in `backend/.env`)
- **Key Secret:** `dummy_razorpay_secret`
- **Webhook Secret:** `dummy_webhook_secret`
- **Mock Sandbox Signature:** `mock_signature_sandbox` (accepted automatically in sandbox simulation mode)

### MQTT Broker (EMQX)
- **Default Broker:** `mqtt://broker.emqx.io:1883`
- **QoS Level:** 1
- **Topics:**
  - `machines/printer001/jobs/assigned`
  - `machines/printer001/status`
  - `machines/printer001/heartbeat`

---

## 5. Admin Dashboard Features

Open `http://localhost:5000/admin/dashboard` in any web browser to:
1. View live machine health (`ONLINE`, `PAPER OK`, `INK OK`, `IDLE`).
2. Toggle Maintenance Mode on `printer001`.
3. View real-time table of recent customer print jobs, pages, copies, and total amounts.
4. Issue instant refunds via the **Refund** button.
