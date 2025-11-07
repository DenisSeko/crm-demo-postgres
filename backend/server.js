import express from 'express';
import cors from 'cors';
import pkg from 'pg';

const { Pool } = pkg;

const app = express();
const PORT = process.env.PORT || 8888;

// Database configuration za Upsun
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

app.use(cors({
  origin: process.env.CORS_ORIGIN || 'http://localhost:5173',
  credentials: true
}));
app.use(express.json());

// Test konekcije na bazu pri pokretanju
async function testDatabaseConnection() {
  try {
    const client = await pool.connect();
    console.log('✅ Database connection successful');
    
    // Provjeri da li postoje tabele
    const tablesResult = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public'
    `);
    
    console.log('📊 Available tables:', tablesResult.rows.map(row => row.table_name));
    client.release();
    return true;
  } catch (error) {
    console.error('❌ Database connection failed:', error.message);
    console.log('💡 DATABASE_URL:', process.env.DATABASE_URL ? 'configured' : 'not configured');
    return false;
  }
}

// Osnovni endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: 'CRM Backend API is running!',
    environment: process.env.NODE_ENV || 'development',
    port: PORT,
    timestamp: new Date().toISOString(),
    database: process.env.DATABASE_URL ? 'configured' : 'not configured'
  });
});

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString()
  });
});

// API health check
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ 
      status: 'OK', 
      environment: process.env.NODE_ENV || 'development',
      database: 'connected',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Health check failed:', error.message);
    res.status(500).json({ 
      status: 'ERROR', 
      environment: process.env.NODE_ENV || 'development',
      database: 'disconnected',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Debug endpoint za provjeru stanja baze
app.get('/api/debug/database', async (req, res) => {
  try {
    const client = await pool.connect();
    
    const tablesResult = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public'
      ORDER BY table_name
    `);

    const tableCounts = {};
    
    for (let table of tablesResult.rows) {
      const tableName = table.table_name;
      try {
        const countResult = await client.query(`SELECT COUNT(*) as count FROM "${tableName}"`);
        tableCounts[tableName] = parseInt(countResult.rows[0].count);
      } catch (tableError) {
        tableCounts[tableName] = -1;
      }
    }

    client.release();

    const debugInfo = {
      environment: process.env.NODE_ENV || 'development',
      tables: tablesResult.rows.map(row => row.table_name),
      counts: tableCounts,
      connection: 'successful',
      timestamp: new Date().toISOString()
    };

    res.json(debugInfo);

  } catch (error) {
    console.error('❌ Debug database error:', error);
    res.status(500).json({
      environment: process.env.NODE_ENV || 'development',
      error: error.message,
      connection: 'failed',
      timestamp: new Date().toISOString()
    });
  }
});

// Start server
app.listen(PORT, '0.0.0.0', async () => {
  console.log(`🚀 Backend server running on port: ${PORT}`);
  console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`📊 PostgreSQL URL: ${process.env.DATABASE_URL ? 'configured' : 'not configured'}`);
  console.log(`🔧 CORS Origin: ${process.env.CORS_ORIGIN || 'http://localhost:5173'}`);
  
  // Testiraj konekciju pri pokretanju
  const dbConnected = await testDatabaseConnection();
  if (!dbConnected) {
    console.log('❌ WARNING: Cannot connect to database!');
  } else {
    console.log('✅ Database connection established');
  }
});