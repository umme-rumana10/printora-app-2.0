import mqtt, { MqttClient } from 'mqtt';
import { config } from '../config';
import { MqttJobAssignedPayload, MachineTelemetryPayload } from '../types';
import { SupabaseService } from './supabase.service';

export class MqttService {
  private static instance: MqttService;
  private client: MqttClient;
  private db: SupabaseService;
  private isConnected = false;

  private constructor() {
    this.db = SupabaseService.getInstance();

    const options: mqtt.IClientOptions = {
      clientId: config.mqtt.clientId,
      clean: true,
      connectTimeout: 5000,
      reconnectPeriod: 3000
    };

    if (config.mqtt.username) {
      options.username = config.mqtt.username;
      options.password = config.mqtt.password;
    }

    console.log(`🔌 [MQTT] Connecting to broker ${config.mqtt.brokerUrl}...`);
    this.client = mqtt.connect(config.mqtt.brokerUrl, options);

    this.client.on('connect', () => {
      this.isConnected = true;
      console.log('✅ [MQTT] Connected to MQTT broker');
      // Subscribe to all machine telemetry & heartbeat topics
      this.client.subscribe('machines/+/status', { qos: 1 });
      this.client.subscribe('machines/+/heartbeat', { qos: 1 });
    });

    this.client.on('message', async (topic: string, message: Buffer) => {
      try {
        const payloadStr = message.toString();
        const parts = topic.split('/');
        const machineId = parts[1];
        const subTopic = parts[2];

        if (subTopic === 'heartbeat') {
          await this.db.updateMachineTelemetry(machineId, { status: 'ONLINE' });
        } else if (subTopic === 'status') {
          const telemetry: MachineTelemetryPayload = JSON.parse(payloadStr);
          await this.db.updateMachineTelemetry(machineId, {
            paper_status: telemetry.paper_status,
            ink_status: telemetry.ink_status,
            printer_status: telemetry.printer_status
          });
          console.log(`📡 [MQTT] Updated telemetry for ${machineId}:`, telemetry);
        }
      } catch (err: any) {
        console.error(`❌ [MQTT] Error processing message on ${topic}:`, err.message);
      }
    });

    this.client.on('error', (err) => {
      console.warn('⚠️ [MQTT] Client error:', err.message);
    });

    this.client.on('offline', () => {
      this.isConnected = false;
      console.warn('⚠️ [MQTT] Client offline');
    });
  }

  public static getInstance(): MqttService {
    if (!MqttService.instance) {
      MqttService.instance = new MqttService();
    }
    return MqttService.instance;
  }

  public async publishJobAssignment(machineId: string, payload: MqttJobAssignedPayload): Promise<void> {
    const topic = `machines/${machineId}/jobs/assigned`;
    const message = JSON.stringify(payload);

    return new Promise((resolve, reject) => {
      this.client.publish(topic, message, { qos: 1 }, (err) => {
        if (err) {
          console.error(`❌ [MQTT] Failed to publish job assignment to ${topic}:`, err.message);
          return reject(err);
        }
        console.log(`🚀 [MQTT] Published job assignment to ${topic} (QoS 1)`);
        resolve();
      });
    });
  }

  public isBrokerConnected(): boolean {
    return this.isConnected;
  }
}
