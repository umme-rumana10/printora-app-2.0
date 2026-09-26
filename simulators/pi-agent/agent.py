#!/usr/bin/env python3
"""
Printora Simulated Raspberry Pi Agent (printer001)
Architecture:
- Connects to MQTT broker (EMQX) with QoS 1
- Subscribes to: machines/printer001/jobs/assigned
- Authenticates with Backend API using device credentials
- Downloads PDF via short-lived signed URL
- Verifies SHA-256 cryptographic checksum
- Emulates hardware print pipeline with exact status transitions:
  DOWNLOADING (2s delay) -> READY_TO_PRINT -> PRINTING (8s delay) -> COMPLETED
- Delivers finalized output to simulators/printed_jobs/
- Periodically reports heartbeat
"""

import os
import sys
import time
import json
import hashlib
import threading
import requests
import paho.mqtt.client as mqtt

if sys.platform.startswith('win'):
    try:
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    except Exception:
        pass

# Configuration
MACHINE_ID = os.getenv("MACHINE_ID", "printer001")
BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:5000")
MQTT_BROKER = os.getenv("MQTT_BROKER", "broker.emqx.io")
MQTT_PORT = int(os.getenv("MQTT_PORT", 1883))
DOWNLOAD_DELAY_SEC = float(os.getenv("DOWNLOAD_DELAY_SEC", "2.0"))
PRINT_DELAY_SEC = float(os.getenv("PRINT_DELAY_SEC", "8.0"))

PRINTED_JOBS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "printed_jobs"))
DOWNLOADS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "downloads"))

os.makedirs(PRINTED_JOBS_DIR, exist_ok=True)
os.makedirs(DOWNLOADS_DIR, exist_ok=True)

class PiAgent:
    def __init__(self):
        self.device_token = None
        self.mqtt_client = None
        self.is_running = True
        self.active_jobs = set()

    def authenticate_device(self):
        """Authenticates machine with backend and retrieves device JWT token."""
        print(f"🔑 [Pi-Agent] Authenticating device '{MACHINE_ID}' at {BACKEND_URL}...")
        try:
            res = requests.post(f"{BACKEND_URL}/device/auth", json={
                "machineId": MACHINE_ID,
                "secretKey": "printer001_secret"
            }, timeout=5)
            if res.status_code == 200:
                data = res.json()
                self.device_token = data.get("token")
                print(f"✅ [Pi-Agent] Authenticated successfully. Token obtained.")
                return True
            else:
                print(f"⚠️ [Pi-Agent] Auth returned status {res.status_code}: {res.text}")
                return False
        except Exception as e:
            print(f"⚠️ [Pi-Agent] Auth connection warning: {e}")
            return False

    def report_status(self, job_id, status, details=None):
        """Reports job status update to backend via device endpoint."""
        headers = {}
        if self.device_token:
            headers["Authorization"] = f"Bearer {self.device_token}"
        try:
            res = requests.post(f"{BACKEND_URL}/device/jobs/{job_id}/status", json={
                "status": status,
                "details": details or {}
            }, headers=headers, timeout=5)
            print(f"📡 [Pi-Agent] Reported Job {job_id} -> {status} (HTTP {res.status_code})")
        except Exception as e:
            print(f"⚠️ [Pi-Agent] Failed to report status to backend: {e}")

    def send_heartbeat(self):
        """Sends periodic heartbeat to MQTT and Backend."""
        while self.is_running:
            try:
                # 1. Backend HTTP Heartbeat
                requests.post(f"{BACKEND_URL}/device/machines/{MACHINE_ID}/heartbeat", json={
                    "paper_status": "OK",
                    "ink_status": "OK",
                    "printer_status": "IDLE" if not self.active_jobs else "PRINTING"
                }, timeout=3)
                
                # 2. MQTT Heartbeat
                if self.mqtt_client and self.mqtt_client.is_connected():
                    self.mqtt_client.publish(f"machines/{MACHINE_ID}/heartbeat", json.dumps({
                        "machineId": MACHINE_ID,
                        "timestamp": time.time(),
                        "status": "ONLINE"
                    }), qos=1)
            except Exception:
                pass
            time.sleep(15)

    def compute_sha256(self, file_path):
        sha256 = hashlib.sha256()
        with open(file_path, "rb") as f:
            for block in iter(lambda: f.read(65536), b""):
                sha256.update(block)
        return sha256.hexdigest()

    def process_job(self, payload):
        job_id = payload.get("jobId")
        download_url = payload.get("downloadUrl")
        expected_checksum = payload.get("checksum")
        settings = payload.get("settings", {})

        print(f"\n========================================================")
        print(f"🖨️ [Pi-Agent] Received Job Assignment: {job_id}")
        print(f"📄 Settings: {settings}")
        print(f"🔗 Download URL: {download_url}")
        print(f"🔒 Expected SHA-256: {expected_checksum}")
        print(f"========================================================")

        self.active_jobs.add(job_id)

        try:
            # 1. DOWNLOADING status
            self.report_status(job_id, "DOWNLOADING")
            print(f"⏳ [Pi-Agent] Simulating download delay ({DOWNLOAD_DELAY_SEC}s)...")
            time.sleep(DOWNLOAD_DELAY_SEC)

            # Download the file
            download_dest = os.path.join(DOWNLOADS_DIR, f"{job_id}.pdf")
            res = requests.get(download_url, stream=True, timeout=10)
            if res.status_code != 200:
                raise Exception(f"Download failed with HTTP {res.status_code}: {res.text}")

            with open(download_dest, "wb") as f:
                for chunk in res.iter_content(chunk_size=8192):
                    f.write(chunk)

            print(f"💾 [Pi-Agent] Download completed: {download_dest}")

            # 2. Verify Checksum
            actual_checksum = self.compute_sha256(download_dest)
            print(f"🔍 [Pi-Agent] Computed Checksum: {actual_checksum}")
            if actual_checksum != expected_checksum:
                raise Exception(f"Checksum mismatch! Expected {expected_checksum} but got {actual_checksum}")

            # 3. READY_TO_PRINT
            self.report_status(job_id, "READY_TO_PRINT")
            time.sleep(1.0)

            # 4. PRINTING
            self.report_status(job_id, "PRINTING")
            print(f"⚙️ [Pi-Agent] Simulating physical printing ({PRINT_DELAY_SEC}s)...")
            time.sleep(PRINT_DELAY_SEC)

            # 5. Mock Printer: Copy to printed_jobs/
            printed_file_path = os.path.join(PRINTED_JOBS_DIR, f"printed_{job_id}.pdf")
            with open(download_dest, "rb") as src, open(printed_file_path, "wb") as dst:
                dst.write(src.read())

            print(f"🎉 [Pi-Agent] Job {job_id} physically completed! Output saved to:")
            print(f"   --> {printed_file_path}")

            # Clean temp download
            if os.path.exists(download_dest):
                os.remove(download_dest)

            # 6. COMPLETED
            self.report_status(job_id, "COMPLETED", {"printed_path": printed_file_path})

        except Exception as e:
            print(f"❌ [Pi-Agent] Job {job_id} FAILED: {e}")
            self.report_status(job_id, "FAILED", {"error": str(e)})
        finally:
            self.active_jobs.discard(job_id)

    def on_mqtt_connect(self, client, userdata, flags, rc, properties=None):
        if rc == 0:
            print(f"✅ [Pi-Agent] Connected to MQTT Broker: {MQTT_BROKER}:{MQTT_PORT}")
            topic = f"machines/{MACHINE_ID}/jobs/assigned"
            client.subscribe(topic, qos=1)
            print(f"📥 [Pi-Agent] Subscribed to topic: {topic} (QoS 1)")
        else:
            print(f"❌ [Pi-Agent] MQTT connection failed with code {rc}")

    def on_mqtt_message(self, client, userdata, msg):
        try:
            payload = json.loads(msg.payload.decode())
            threading.Thread(target=self.process_job, args=(payload,), daemon=True).start()
        except Exception as e:
            print(f"❌ [Pi-Agent] Error parsing MQTT message: {e}")

    def start(self):
        self.authenticate_device()

        # Start background heartbeat thread
        threading.Thread(target=self.send_heartbeat, daemon=True).start()

        # Setup MQTT Client
        client_id = f"pi_agent_{MACHINE_ID}_{int(time.time())}"
        try:
            # Paho MQTT 2.0+ support
            self.mqtt_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id)
        except AttributeError:
            self.mqtt_client = mqtt.Client(client_id)

        self.mqtt_client.on_connect = self.on_mqtt_connect
        self.mqtt_client.on_message = self.on_mqtt_message

        print(f"🔌 [Pi-Agent] Connecting to MQTT broker {MQTT_BROKER}...")
        try:
            self.mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
            self.mqtt_client.loop_forever()
        except KeyboardInterrupt:
            print("\n🛑 [Pi-Agent] Stopping agent...")
            self.is_running = False
            self.mqtt_client.disconnect()

if __name__ == "__main__":
    agent = PiAgent()
    agent.start()
