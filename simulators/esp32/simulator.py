#!/usr/bin/env python3
"""
Printora Simulated ESP32 Hardware State Controller
Allows toggling and publishing real-time telemetry for printer001:
- Paper OK / Paper Out
- Ink OK / Ink Low
- Door Closed / Door Open
- Temperature Normal / Temperature Warning
Supports both interactive CLI menu and headless command-line script flags.
"""

import os
import sys
import time
import json
import argparse
import paho.mqtt.client as mqtt

MACHINE_ID = os.getenv("MACHINE_ID", "printer001")
MQTT_BROKER = os.getenv("MQTT_BROKER", "broker.emqx.io")
MQTT_PORT = int(os.getenv("MQTT_PORT", 1883))

class ESP32Simulator:
    def __init__(self):
        self.paper_status = "OK"        # OK, LOW, OUT
        self.ink_status = "OK"          # OK, LOW, EMPTY
        self.door_status = "CLOSED"     # CLOSED, OPEN
        self.temp_status = "NORMAL"     # NORMAL, WARNING
        self.temperature = 34.5         # Celsius

        client_id = f"esp32_{MACHINE_ID}_{int(time.time())}"
        try:
            self.mqtt_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id)
        except AttributeError:
            self.mqtt_client = mqtt.Client(client_id)

    def connect(self):
        print(f"🔌 [ESP32] Connecting to MQTT broker {MQTT_BROKER}:{MQTT_PORT}...")
        self.mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
        self.mqtt_client.loop_start()
        time.sleep(1)
        print(f"✅ [ESP32] Connected successfully.")

    def publish_telemetry(self):
        topic = f"machines/{MACHINE_ID}/status"
        payload = {
            "machineId": MACHINE_ID,
            "timestamp": time.time(),
            "paper_status": self.paper_status,
            "ink_status": self.ink_status,
            "door_status": self.door_status,
            "temperature_celsius": self.temperature,
            "printer_status": "ERROR" if (self.paper_status == "OUT" or self.door_status == "OPEN") else "IDLE"
        }
        data_str = json.dumps(payload)
        self.mqtt_client.publish(topic, data_str, qos=1)
        print(f"📡 [ESP32] Published state to {topic}:")
        print(f"   --> Paper: {self.paper_status} | Ink: {self.ink_status} | Door: {self.door_status} | Temp: {self.temperature}°C")

    def toggle_paper(self, status=None):
        if status:
            self.paper_status = status.upper()
        else:
            self.paper_status = "OUT" if self.paper_status == "OK" else "OK"
        self.publish_telemetry()

    def toggle_ink(self, status=None):
        if status:
            self.ink_status = status.upper()
        else:
            self.ink_status = "LOW" if self.ink_status == "OK" else "OK"
        self.publish_telemetry()

    def toggle_door(self, status=None):
        if status:
            self.door_status = status.upper()
        else:
            self.door_status = "OPEN" if self.door_status == "CLOSED" else "CLOSED"
        self.publish_telemetry()

    def toggle_temp(self, status=None):
        if status:
            self.temp_status = status.upper()
            self.temperature = 68.0 if self.temp_status == "WARNING" else 34.5
        else:
            if self.temp_status == "NORMAL":
                self.temp_status = "WARNING"
                self.temperature = 68.0
            else:
                self.temp_status = "NORMAL"
                self.temperature = 34.5
        self.publish_telemetry()

    def interactive_menu(self):
        while True:
            print("\n" + "="*50)
            print(f"⚙️ ESP32 HARDWARE STATE SIMULATOR ({MACHINE_ID})")
            print("="*50)
            print(f"1. Toggle Paper Status  [Current: {self.paper_status}]")
            print(f"2. Toggle Ink Status    [Current: {self.ink_status}]")
            print(f"3. Toggle Door Status   [Current: {self.door_status}]")
            print(f"4. Toggle Temp Warning  [Current: {self.temp_status} ({self.temperature}°C)]")
            print("5. Publish Current State")
            print("6. Exit")
            print("="*50)
            choice = input("Enter choice (1-6): ").strip()

            if choice == "1":
                self.toggle_paper()
            elif choice == "2":
                self.toggle_ink()
            elif choice == "3":
                self.toggle_door()
            elif choice == "4":
                self.toggle_temp()
            elif choice == "5":
                self.publish_telemetry()
            elif choice == "6":
                print("Exiting ESP32 simulator.")
                self.mqtt_client.loop_stop()
                self.mqtt_client.disconnect()
                break
            else:
                print("Invalid option.")

def main():
    parser = argparse.ArgumentParser(description="Printora ESP32 Hardware State Simulator")
    parser.add_argument("--set-paper", choices=["OK", "LOW", "OUT"], help="Set paper status")
    parser.add_argument("--set-ink", choices=["OK", "LOW", "EMPTY"], help="Set ink status")
    parser.add_argument("--set-door", choices=["CLOSED", "OPEN"], help="Set door status")
    parser.add_argument("--set-temp", choices=["NORMAL", "WARNING"], help="Set temperature warning")
    parser.add_argument("--interactive", action="store_true", help="Launch interactive CLI menu")

    args = parser.parse_args()

    sim = ESP32Simulator()
    sim.connect()

    if args.set_paper:
        sim.toggle_paper(args.set_paper)
    if args.set_ink:
        sim.toggle_ink(args.set_ink)
    if args.set_door:
        sim.toggle_door(args.set_door)
    if args.set_temp:
        sim.toggle_temp(args.set_temp)

    if args.interactive or (not any([args.set_paper, args.set_ink, args.set_door, args.set_temp])):
        sim.interactive_menu()
    else:
        # Allow MQTT publish to complete
        time.sleep(1)
        sim.mqtt_client.loop_stop()
        sim.mqtt_client.disconnect()

if __name__ == "__main__":
    main()
