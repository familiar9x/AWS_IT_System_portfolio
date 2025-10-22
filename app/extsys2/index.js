import express from 'express';

const app = express();
app.use(express.json());

// Mock network device data
const mockDevices = [
  {
    id: 'sw-001',
    name: 'Core Switch 01',
    type: 'switch',
    status: 'active',
    ip: '10.0.0.1',
    location: 'Data Center A - Rack 1',
    ports: 48,
    uptime: '245 days',
    lastSeen: new Date().toISOString()
  },
  {
    id: 'fw-001',
    name: 'Firewall 01',
    type: 'firewall',
    status: 'active',
    ip: '10.0.0.254',
    location: 'Data Center A - DMZ',
    throughput: '1Gbps',
    lastSeen: new Date().toISOString()
  },
  {
    id: 'rtr-001',
    name: 'Core Router 01',
    type: 'router',
    status: 'active',
    ip: '10.0.0.2',
    location: 'Data Center A - Core',
    interfaces: 8,
    lastSeen: new Date().toISOString()
  },
  {
    id: 'ap-001',
    name: 'Wireless AP 01',
    type: 'access_point',
    status: 'active',
    ip: '10.0.10.50',
    location: 'Office Floor 1',
    clients: 23,
    lastSeen: new Date().toISOString()
  }
];

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    service: 'extsys2',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// Get all devices
app.get('/devices', (req, res) => {
  const { type, status, location } = req.query;
  
  let devices = [...mockDevices];
  
  if (type) {
    devices = devices.filter(device => device.type === type);
  }
  
  if (status) {
    devices = devices.filter(device => device.status === status);
  }
  
  if (location) {
    devices = devices.filter(device => 
      device.location.toLowerCase().includes(location.toLowerCase())
    );
  }
  
  res.json({
    data: devices,
    total: devices.length,
    source: 'extsys2'
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

// Get device types
app.get('/device-types', (req, res) => {
  const types = [...new Set(mockDevices.map(d => d.type))];
  res.json({ data: types });
});

const PORT = process.env.PORT || 8002;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🌐 External System 2 (Network) running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
});