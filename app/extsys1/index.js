import express from 'express';

const app = express();
app.use(express.json());

// Mock device data
const mockDevices = [
  {
    id: 'srv-001',
    name: 'Web Server 01',
    type: 'server',
    status: 'running',
    ip: '10.0.1.100',
    environment: 'production',
    lastSeen: new Date().toISOString()
  },
  {
    id: 'db-001',
    name: 'Database Server 01',
    type: 'database',
    status: 'running',
    ip: '10.0.2.100',
    environment: 'production',
    lastSeen: new Date().toISOString()
  },
  {
    id: 'lb-001',
    name: 'Load Balancer 01',
    type: 'load_balancer',
    status: 'running',
    ip: '10.0.1.10',
    environment: 'production',
    lastSeen: new Date().toISOString()
  }
];

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    service: 'extsys1',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// Get all devices
app.get('/devices', (req, res) => {
  const { type, status } = req.query;
  
  let devices = [...mockDevices];
  
  if (type) {
    devices = devices.filter(device => device.type === type);
  }
  
  if (status) {
    devices = devices.filter(device => device.status === status);
  }
  
  res.json({
    data: devices,
    total: devices.length,
    source: 'extsys1'
  });
});

// Get device by ID
app.get('/devices/:id', (req, res) => {
  const device = mockDevices.find(d => d.id === req.params.id);
  
  if (!device) {
    return res.status(404).json({ 
      error: 'Device not found',
      id: req.params.id 
    });
  }
  
  res.json({ data: device });
});

const PORT = process.env.PORT || 8001;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🔌 External System 1 running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
});