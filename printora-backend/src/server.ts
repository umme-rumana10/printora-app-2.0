import app from './app';
import { config } from './config';
import { MqttService } from './services/mqtt.service';

// Initialize MQTT connection
MqttService.getInstance();

const PORT = config.port;

app.listen(PORT, () => {
  console.log(`
=====================================================
🚀 PRINTORA BACKEND SERVER STARTED
=====================================================
📡 Port:           ${PORT}
🌍 Environment:    ${config.nodeEnv}
🖨️ Admin Panel:    http://localhost:${PORT}/admin/dashboard
💚 Health Endpoint: http://localhost:${PORT}/health
📡 MQTT Broker:    ${config.mqtt.brokerUrl}
=====================================================
  `);
});
