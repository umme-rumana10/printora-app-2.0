import express from 'express';
import cors from 'cors';
import mobileRoutes from './routes/mobile.routes';
import webhookRoutes from './routes/webhook.routes';
import deviceRoutes from './routes/device.routes';
import adminRoutes from './routes/admin.routes';
import { SupabaseService } from './services/supabase.service';
import { MqttService } from './services/mqtt.service';

const app = express();

// Middlewares
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Health Check
app.get('/health', (_req, res) => {
  const mqtt = MqttService.getInstance();
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    mqttConnected: mqtt.isBrokerConnected(),
    version: '1.0.0'
  });
});

// Mount Routes
app.use('/', mobileRoutes);
app.use('/webhooks', webhookRoutes);
app.use('/device', deviceRoutes);
app.use('/admin', adminRoutes);

// Admin Dashboard Web Interface
app.get('/admin/dashboard', async (_req, res) => {
  const db = SupabaseService.getInstance();
  const machines = await db.getAllMachines();
  const jobs = await db.getAllJobs();

  const html = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Printora - Fleet & Kiosk Admin Dashboard</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #0d1117;
      --card-bg: #161b22;
      --border: #30363d;
      --text: #c9d1d9;
      --heading: #f0f6fc;
      --accent: #2563eb;
      --accent-hover: #1d4ed8;
      --success: #238636;
      --warning: #d29922;
      --danger: #da3633;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
      background-color: var(--bg);
      color: var(--text);
      padding: 24px;
    }
    header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding-bottom: 20px;
      border-bottom: 1px solid var(--border);
      margin-bottom: 24px;
    }
    h1 { font-size: 24px; color: var(--heading); display: flex; align-items: center; gap: 10px; }
    .badge {
      display: inline-block;
      padding: 4px 10px;
      border-radius: 12px;
      font-size: 12px;
      font-weight: 600;
      text-transform: uppercase;
    }
    .badge-online { background: #23863622; color: #3fb950; border: 1px solid #238636; }
    .badge-offline { background: #da363322; color: #f85149; border: 1px solid #da3633; }
    .badge-warning { background: #d2992222; color: #e3b341; border: 1px solid #d29922; }
    .badge-info { background: #2563eb22; color: #58a6ff; border: 1px solid #2563eb; }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
      gap: 20px;
      margin-bottom: 30px;
    }
    .card {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 20px;
    }
    .card-title {
      font-size: 16px;
      font-weight: 600;
      color: var(--heading);
      margin-bottom: 16px;
      display: flex;
      justify-content: space-between;
    }
    .metric-row {
      display: flex;
      justify-content: space-between;
      padding: 8px 0;
      border-bottom: 1px solid #21262d;
    }
    .metric-row:last-child { border-bottom: none; }
    button {
      background: var(--accent);
      color: white;
      border: none;
      border-radius: 6px;
      padding: 6px 14px;
      cursor: pointer;
      font-weight: 600;
      transition: background 0.2s;
    }
    button:hover { background: var(--accent-hover); }
    button.btn-danger { background: var(--danger); }
    button.btn-warning { background: var(--warning); color: #000; }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 10px;
    }
    th, td {
      text-align: left;
      padding: 12px;
      border-bottom: 1px solid var(--border);
      font-size: 14px;
    }
    th { color: var(--heading); font-weight: 600; background: #161b22; }
    tr:hover { background: #21262d; }
  </style>
</head>
<body>
  <header>
    <h1>🖨️ Printora Vending Machine Control Panel</h1>
    <div><span class="badge badge-online">Backend Live</span></div>
  </header>

  <h2 style="color: var(--heading); margin-bottom: 15px; font-size: 18px;">Fleet Status</h2>
  <div class="grid">
    ${machines.map(m => `
      <div class="card" id="machine-${m.id}">
        <div class="card-title">
          <span>Machine: <strong>${m.id}</strong></span>
          <span class="badge ${m.status === 'ONLINE' ? 'badge-online' : 'badge-offline'}">${m.status}</span>
        </div>
        <div class="metric-row"><span>Location:</span><span>${m.location}</span></div>
        <div class="metric-row"><span>Paper Status:</span><span class="badge ${m.paper_status === 'OK' ? 'badge-online' : 'badge-warning'}">${m.paper_status}</span></div>
        <div class="metric-row"><span>Ink Status:</span><span class="badge ${m.ink_status === 'OK' ? 'badge-online' : 'badge-warning'}">${m.ink_status}</span></div>
        <div class="metric-row"><span>Printer Engine:</span><span class="badge badge-info">${m.printer_status}</span></div>
        <div class="metric-row"><span>Maintenance Mode:</span><span>${m.maintenance_mode ? 'ENABLED' : 'DISABLED'}</span></div>
        <div style="margin-top: 15px; display: flex; gap: 10px;">
          <button class="btn-warning" onclick="toggleMaintenance('${m.id}', ${!m.maintenance_mode})">
            ${m.maintenance_mode ? 'Exit Maintenance' : 'Toggle Maintenance'}
          </button>
        </div>
      </div>
    `).join('')}
  </div>

  <h2 style="color: var(--heading); margin-bottom: 15px; font-size: 18px;">Recent Print Jobs</h2>
  <div class="card" style="overflow-x: auto;">
    <table>
      <thead>
        <tr>
          <th>Job ID</th>
          <th>Machine</th>
          <th>Pages / Copies</th>
          <th>Type</th>
          <th>Amount</th>
          <th>Status</th>
          <th>Created</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>
        ${jobs.length === 0 ? '<tr><td colspan="8" style="text-align:center; padding: 20px;">No jobs recorded yet.</td></tr>' : ''}
        ${jobs.map(j => `
          <tr>
            <td><code style="font-size:12px;">${j.id.slice(0, 8)}...</code></td>
            <td>${j.machine_id}</td>
            <td>${j.pages} pgs × ${j.copies}</td>
            <td>${j.color ? 'Color' : 'B&W'} ${j.duplex ? '(Duplex)' : ''}</td>
            <td>₹${j.amount.toFixed(2)}</td>
            <td><span class="badge badge-info">${j.status}</span></td>
            <td>${new Date(j.created_at).toLocaleTimeString()}</td>
            <td>
              ${j.status !== 'REFUNDED' ? `<button class="btn-danger" style="padding: 4px 8px; font-size: 12px;" onclick="refundJob('${j.id}')">Refund</button>` : '<span class="badge badge-warning">REFUNDED</span>'}
            </td>
          </tr>
        `).join('')}
      </tbody>
    </table>
  </div>

  <script>
    async function toggleMaintenance(machineId, mode) {
      await fetch('/admin/machines/' + machineId + '/maintenance', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ maintenanceMode: mode })
      });
      location.reload();
    }

    async function refundJob(jobId) {
      if (!confirm('Are you sure you want to refund this job?')) return;
      const res = await fetch('/admin/jobs/' + jobId + '/refund', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ reason: 'Admin dashboard triggered refund' })
      });
      const data = await res.json();
      alert(data.message || 'Refund recorded');
      location.reload();
    }
  </script>
</body>
</html>
  `;
  res.send(html);
});

export default app;
