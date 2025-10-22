import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import sql from 'mssql';
import dotenv from 'dotenv';

dotenv.config();

const app = express();

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
  credentials: true
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Database configuration
const dbConfig = {
  server: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'CMDB',
  user: process.env.DB_USER || 'sa',
  password: process.env.DB_PASS || '',
  port: parseInt(process.env.DB_PORT) || 1433,
  options: {
    encrypt: true,
    trustServerCertificate: true,
    enableArithAbort: true,
    connectionTimeout: 30000,
    requestTimeout: 30000
  },
  pool: {
    max: 10,
    min: 0,
    idleTimeoutMillis: 30000
  }
};

let pool = null;

// Initialize database connection
async function initDatabase() {
  try {
    pool = await sql.connect(dbConfig);
    console.log('✅ Database connected successfully');
    
    // Create basic tables if not exist
    await createTablesIfNotExist();
  } catch (err) {
    console.error('❌ Database connection failed:', err);
    // Don't exit in development, allow API to run without DB
    if (process.env.NODE_ENV === 'production') {
      process.exit(1);
    }
  }
}

async function createTablesIfNotExist() {
  try {
    const request = pool.request();
    
    // Create Configuration Items table
    await request.query(`
      IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='ConfigurationItems' AND xtype='U')
      CREATE TABLE ConfigurationItems (
        id INT IDENTITY(1,1) PRIMARY KEY,
        name NVARCHAR(255) NOT NULL,
        type NVARCHAR(100) NOT NULL,
        status NVARCHAR(50) DEFAULT 'Active',
        environment NVARCHAR(50),
        owner NVARCHAR(255),
        description NTEXT,
        created_at DATETIME2 DEFAULT GETDATE(),
        updated_at DATETIME2 DEFAULT GETDATE()
      )
    `);
    
    console.log('✅ Database tables verified/created');
  } catch (err) {
    console.error('❌ Error creating tables:', err);
  }
}

// Middleware for database connection check
const requireDB = (req, res, next) => {
  if (!pool) {
    return res.status(503).json({ 
      error: 'Database not available',
      code: 'DB_UNAVAILABLE'
    });
  }
  next();
};

// Health check endpoint
app.get('/health', async (req, res) => {
  const health = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: process.env.APP_VERSION || '1.0.0',
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development'
  };

  // Check database connection
  try {
    if (pool) {
      await pool.request().query('SELECT 1');
      health.database = 'connected';
    } else {
      health.database = 'disconnected';
    }
  } catch (err) {
    health.database = 'error';
    health.dbError = err.message;
  }

  // Check external systems
  health.externalSystems = {
    extsys1: process.env.EXTSYS1_URL || 'not_configured',
    extsys2: process.env.EXTSYS2_URL || 'not_configured'
  };

  res.json(health);
});

// Configuration Items endpoints
app.get('/api/v1/ci', requireDB, async (req, res) => {
  try {
    const { type, status, limit = 50, offset = 0 } = req.query;
    
    let query = 'SELECT * FROM ConfigurationItems WHERE 1=1';
    const params = [];
    
    if (type) {
      query += ' AND type = @type';
      params.push({ name: 'type', type: sql.NVarChar, value: type });
    }
    
    if (status) {
      query += ' AND status = @status';
      params.push({ name: 'status', type: sql.NVarChar, value: status });
    }
    
    query += ' ORDER BY created_at DESC OFFSET @offset ROWS FETCH NEXT @limit ROWS ONLY';
    params.push(
      { name: 'offset', type: sql.Int, value: parseInt(offset) },
      { name: 'limit', type: sql.Int, value: parseInt(limit) }
    );
    
    const request = pool.request();
    params.forEach(param => {
      request.input(param.name, param.type, param.value);
    });
    
    const result = await request.query(query);
    
    res.json({
      data: result.recordset,
      pagination: {
        limit: parseInt(limit),
        offset: parseInt(offset),
        total: result.recordset.length
      }
    });
  } catch (err) {
    console.error('Error fetching CIs:', err);
    res.status(500).json({ 
      error: 'Failed to fetch configuration items',
      code: 'FETCH_ERROR'
    });
  }
});

app.post('/api/v1/ci', requireDB, async (req, res) => {
  try {
    const { name, type, status = 'Active', environment, owner, description } = req.body;
    
    if (!name || !type) {
      return res.status(400).json({ 
        error: 'Name and type are required',
        code: 'VALIDATION_ERROR'
      });
    }
    
    const request = pool.request();
    const result = await request
      .input('name', sql.NVarChar, name)
      .input('type', sql.NVarChar, type)
      .input('status', sql.NVarChar, status)
      .input('environment', sql.NVarChar, environment)
      .input('owner', sql.NVarChar, owner)
      .input('description', sql.NText, description)
      .query(`
        INSERT INTO ConfigurationItems (name, type, status, environment, owner, description)
        OUTPUT INSERTED.*
        VALUES (@name, @type, @status, @environment, @owner, @description)
      `);
    
    res.status(201).json({
      message: 'Configuration item created successfully',
      data: result.recordset[0]
    });
  } catch (err) {
    console.error('Error creating CI:', err);
    res.status(500).json({ 
      error: 'Failed to create configuration item',
      code: 'CREATE_ERROR'
    });
  }
});

app.get('/api/v1/ci/:id', requireDB, async (req, res) => {
  try {
    const { id } = req.params;
    
    const request = pool.request();
    const result = await request
      .input('id', sql.Int, parseInt(id))
      .query('SELECT * FROM ConfigurationItems WHERE id = @id');
    
    if (result.recordset.length === 0) {
      return res.status(404).json({ 
        error: 'Configuration item not found',
        code: 'NOT_FOUND'
      });
    }
    
    res.json({ data: result.recordset[0] });
  } catch (err) {
    console.error('Error fetching CI:', err);
    res.status(500).json({ 
      error: 'Failed to fetch configuration item',
      code: 'FETCH_ERROR'
    });
  }
});

// External systems integration endpoints
app.get('/api/v1/external/devices', async (req, res) => {
  try {
    const devices = [];
    
    // Fetch from external system 1
    if (process.env.EXTSYS1_URL) {
      try {
        // In real implementation, use fetch or axios
        devices.push({
          source: 'extsys1',
          status: 'available',
          url: process.env.EXTSYS1_URL
        });
      } catch (err) {
        devices.push({
          source: 'extsys1',
          status: 'error',
          error: err.message
        });
      }
    }
    
    // Fetch from external system 2
    if (process.env.EXTSYS2_URL) {
      try {
        devices.push({
          source: 'extsys2',
          status: 'available',
          url: process.env.EXTSYS2_URL
        });
      } catch (err) {
        devices.push({
          source: 'extsys2',
          status: 'error',
          error: err.message
        });
      }
    }
    
    res.json({ 
      message: 'External systems status',
      data: devices,
      timestamp: new Date().toISOString()
    });
  } catch (err) {
    console.error('Error checking external systems:', err);
    res.status(500).json({ 
      error: 'Failed to check external systems',
      code: 'EXTERNAL_ERROR'
    });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ 
    error: 'Internal Server Error',
    code: 'INTERNAL_ERROR',
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ 
    error: 'Endpoint not found',
    code: 'NOT_FOUND',
    path: req.originalUrl
  });
});

const PORT = process.env.PORT || 3000;

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('🔄 SIGTERM received, shutting down gracefully...');
  if (pool) {
    await pool.close();
  }
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('🔄 SIGINT received, shutting down gracefully...');
  if (pool) {
    await pool.close();
  }
  process.exit(0);
});

// Initialize and start server
initDatabase().then(() => {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 CMDB API server running on port ${PORT}`);
    console.log(`📊 Health check: http://localhost:${PORT}/health`);
    console.log(`🔌 Environment: ${process.env.NODE_ENV || 'development'}`);
  });
}).catch(err => {
  console.error('❌ Failed to start server:', err);
  process.exit(1);
});