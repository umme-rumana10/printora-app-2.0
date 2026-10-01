import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

export const config = {
  port: parseInt(process.env.PORT || '5000', 10),
  nodeEnv: process.env.NODE_ENV || 'development',
  publicUrl: (process.env.PUBLIC_URL || `http://localhost:${process.env.PORT || '5000'}`).replace(/\/+$/, ''),

  supabase: {
    url: process.env.SUPABASE_URL || 'https://dummy.supabase.co',
    anonKey: process.env.SUPABASE_ANON_KEY || 'dummy-anon-key',
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || 'dummy-service-role-key',
    storageBucket: process.env.SUPABASE_STORAGE_BUCKET || 'printora-files',
  },

  razorpay: {
    keyId: process.env.RAZORPAY_KEY_ID || 'rzp_test_dummy_key_id',
    keySecret: process.env.RAZORPAY_KEY_SECRET || 'dummy_razorpay_secret',
    webhookSecret: process.env.RAZORPAY_WEBHOOK_SECRET || 'dummy_webhook_secret',
  },

  mqtt: {
    brokerUrl: process.env.MQTT_BROKER_URL || 'mqtt://broker.emqx.io:1883',
    username: process.env.MQTT_USERNAME || '',
    password: process.env.MQTT_PASSWORD || '',
    clientId: process.env.MQTT_CLIENT_ID || `printora_backend_${Math.random().toString(16).slice(2, 8)}`,
  },

  jwt: {
    secret: process.env.JWT_SECRET || 'super_secret_printora_device_jwt_key_2026',
    downloadUrlExpiresSeconds: parseInt(process.env.DOWNLOAD_URL_EXPIRES_SECONDS || '300', 10),
  },

  pricing: {
    bwPerPage: 2.0, // INR
    colorPerPage: 10.0, // INR
  }
};
