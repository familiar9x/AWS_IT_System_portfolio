#!/usr/bin/env node
/**
 * Automated Ingest Service
 * Fetches data from external systems and merges into CMDB
 * Triggered by EventBridge every hour
 */

const sql = require('mssql');
const axios = require('axios');

const config = {
  server: process.env.DB_HOST,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  options: {
    encrypt: true,
    trustServerCertificate: false,
    requestTimeout: 30000,
  },
  pool: {
    max: 5,
    min: 1,
    idleTimeoutMillis: 30000,
  }
};

const EXTSYS1_URL = process.env.EXTSYS1_URL || 'http://localhost:8001';
const EXTSYS2_URL = process.env.EXTSYS2_URL || 'http://localhost:8002';

async function fetchExternalData() {
  console.log('🔄 Starting data fetch from external systems...');
  
  try {
    // Fetch from External System 1 (Server/Infrastructure data)
    console.log(`📡 Fetching from External System 1: ${EXTSYS1_URL}`);
    const ext1Response = await axios.get(`${EXTSYS1_URL}/api/devices`, {
      timeout: 10000,
      headers: { 'Accept': 'application/json' }
    });
    
    // Fetch from External System 2 (Network equipment data)
    console.log(`📡 Fetching from External System 2: ${EXTSYS2_URL}`);
    const ext2Response = await axios.get(`${EXTSYS2_URL}/api/devices`, {
      timeout: 10000,
      headers: { 'Accept': 'application/json' }
    });
    
    return {
      extsys1: ext1Response.data || [],
      extsys2: ext2Response.data || []
    };
    
  } catch (error) {
    console.error('❌ Error fetching external data:', error.message);
    throw error;
  }
}

async function mergeDeviceData(pool, externalData) {
  console.log('🔄 Starting device data merge...');
  
  const transaction = new sql.Transaction(pool);
  await transaction.begin();
  
  try {
    let totalInserted = 0;
    let totalUpdated = 0;
    
    // Process External System 1 data
    for (const device of externalData.extsys1) {
      const result = await mergeDevice(transaction, device, 'ExternalSystem1');
      if (result === 'INSERT') totalInserted++;
      else if (result === 'UPDATE') totalUpdated++;
    }
    
    // Process External System 2 data
    for (const device of externalData.extsys2) {
      const result = await mergeDevice(transaction, device, 'ExternalSystem2');
      if (result === 'INSERT') totalInserted++;
      else if (result === 'UPDATE') totalUpdated++;
    }
    
    await transaction.commit();
    
    console.log(`✅ Merge completed: ${totalInserted} inserted, ${totalUpdated} updated`);
    return { inserted: totalInserted, updated: totalUpdated };
    
  } catch (error) {
    await transaction.rollback();
    console.error('❌ Error during merge:', error.message);
    throw error;
  }
}

async function mergeDevice(transaction, deviceData, source) {
  const request = new sql.Request(transaction);
  
  // MERGE statement with UPSERT logic based on SerialNumber
  const mergeQuery = `
    MERGE [dbo].[Devices] AS target
    USING (SELECT 
      @Name as Name,
      @SerialNumber as SerialNumber,
      @Type as Type,
      @Status as Status,
      @Environment as Environment,
      @Owner as Owner,
      @Location as Location,
      @MaStartDate as MaStartDate,
      @MaEndDate as MaEndDate,
      @MaCost as MaCost,
      @PurchaseDate as PurchaseDate,
      @PurchaseCost as PurchaseCost,
      @Vendor as Vendor,
      @Model as Model,
      @Description as Description
    ) AS source ON target.SerialNumber = source.SerialNumber
    WHEN MATCHED THEN
      UPDATE SET
        Name = source.Name,
        Type = source.Type,
        Status = source.Status,
        Environment = source.Environment,
        Owner = source.Owner,
        Location = source.Location,
        MaStartDate = source.MaStartDate,
        MaEndDate = source.MaEndDate,
        MaCost = source.MaCost,
        PurchaseDate = source.PurchaseDate,
        PurchaseCost = source.PurchaseCost,
        Vendor = source.Vendor,
        Model = source.Model,
        Description = source.Description,
        UpdatedAt = GETDATE()
    WHEN NOT MATCHED THEN
      INSERT (Name, SerialNumber, Type, Status, Environment, Owner, Location,
              MaStartDate, MaEndDate, MaCost, PurchaseDate, PurchaseCost,
              Vendor, Model, Description)
      VALUES (source.Name, source.SerialNumber, source.Type, source.Status,
              source.Environment, source.Owner, source.Location,
              source.MaStartDate, source.MaEndDate, source.MaCost,
              source.PurchaseDate, source.PurchaseCost,
              source.Vendor, source.Model, source.Description)
    OUTPUT $action;
  `;
  
  // Prepare parameters
  request.input('Name', sql.NVarChar(255), deviceData.name || deviceData.Name || 'Unknown');
  request.input('SerialNumber', sql.NVarChar(100), deviceData.serialNumber || deviceData.SerialNumber || deviceData.serial);
  request.input('Type', sql.NVarChar(100), deviceData.type || deviceData.Type || 'Unknown');
  request.input('Status', sql.NVarChar(50), deviceData.status || deviceData.Status || 'Active');
  request.input('Environment', sql.NVarChar(50), deviceData.environment || deviceData.Environment || 'Production');
  request.input('Owner', sql.NVarChar(255), deviceData.owner || deviceData.Owner || source);
  request.input('Location', sql.NVarChar(255), deviceData.location || deviceData.Location || 'Unknown');
  
  // MA dates and costs
  request.input('MaStartDate', sql.Date, deviceData.maStartDate || deviceData.MaStartDate || null);
  request.input('MaEndDate', sql.Date, deviceData.maEndDate || deviceData.MaEndDate || null);
  request.input('MaCost', sql.Decimal(10,2), deviceData.maCost || deviceData.MaCost || 0);
  
  // Purchase info
  request.input('PurchaseDate', sql.Date, deviceData.purchaseDate || deviceData.PurchaseDate || null);
  request.input('PurchaseCost', sql.Decimal(10,2), deviceData.purchaseCost || deviceData.PurchaseCost || 0);
  
  // Vendor info
  request.input('Vendor', sql.NVarChar(255), deviceData.vendor || deviceData.Vendor || 'Unknown');
  request.input('Model', sql.NVarChar(255), deviceData.model || deviceData.Model || 'Unknown');
  request.input('Description', sql.NText, deviceData.description || deviceData.Description || `Imported from ${source}`);
  
  const result = await request.query(mergeQuery);
  return result.recordset[0] || 'UNKNOWN';
}

async function recordIngestRun(pool, stats, status, errorMessage = null) {
  try {
    const request = new sql.Request(pool);
    
    // Log ingest run to DeviceChanges for audit
    const logQuery = `
      INSERT INTO [dbo].[DeviceChanges] 
      (DeviceId, Field, OldValue, NewValue, UserId, ChangeReason)
      VALUES 
      (0, 'IngestRun', @Status, @Stats, 'system', @Reason)
    `;
    
    request.input('Status', sql.NVarChar(50), status);
    request.input('Stats', sql.NVarChar(500), JSON.stringify(stats));
    request.input('Reason', sql.NVarChar(255), errorMessage || 'Automated ingest from external systems');
    
    await request.query(logQuery);
    
  } catch (error) {
    console.error('⚠️ Failed to record ingest run:', error.message);
  }
}

async function main() {
  console.log('🚀 Starting CMDB Automated Ingest...');
  console.log('⏰ Timestamp:', new Date().toISOString());
  
  let pool;
  let stats = { inserted: 0, updated: 0, errors: 0 };
  
  try {
    // Connect to database
    console.log('📊 Connecting to database...');
    pool = await sql.connect(config);
    console.log('✅ Database connected');
    
    // Fetch external data
    const externalData = await fetchExternalData();
    console.log(`📊 Fetched ${externalData.extsys1.length} devices from ExtSys1, ${externalData.extsys2.length} from ExtSys2`);
    
    // Merge data
    stats = await mergeDeviceData(pool, externalData);
    
    // Record successful run
    await recordIngestRun(pool, stats, 'SUCCESS');
    
    console.log('🎉 Ingest completed successfully!');
    console.log(`📈 Summary: ${stats.inserted} inserted, ${stats.updated} updated`);
    
    process.exit(0);
    
  } catch (error) {
    stats.errors = 1;
    console.error('💥 Ingest failed:', error.message);
    console.error('Stack trace:', error.stack);
    
    if (pool) {
      await recordIngestRun(pool, stats, 'FAILED', error.message);
    }
    
    process.exit(1);
    
  } finally {
    if (pool) {
      await pool.close();
      console.log('📊 Database connection closed');
    }
  }
}

// Handle signals gracefully
process.on('SIGTERM', () => {
  console.log('🛑 Received SIGTERM, shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('🛑 Received SIGINT, shutting down gracefully...');
  process.exit(0);
});

// Run if called directly
if (require.main === module) {
  main().catch(error => {
    console.error('💥 Unhandled error:', error);
    process.exit(1);
  });
}
