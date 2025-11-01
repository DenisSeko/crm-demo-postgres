// server.js
import express from 'express';
import cors from 'cors';
import pkg from 'pg';
const { Pool } = pkg;
import fs from 'fs';
import path from 'path';

const app = express();
const PORT = process.env.PORT || 3001;

// ⭐⭐⭐ DATABASE INIT - JEDNOSTAVNO I EFIKASNO ⭐⭐⭐

// Ažurirane CORS postavke za production i development
app.use(cors({
  origin: [
    'https://crm-stgaing-app.vercel.app',
    'https://crm-staging-app.vercel.app', 
    'http://localhost:5173',
    'http://localhost:3000'
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

async function initializeDatabase() {
    console.log('🔧 Initializing database...');
    
    const pool = new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: { rejectUnauthorized: false }
    });

    try {
        const client = await pool.connect();
        
        // Prvo provjeri postoje li tabele
        const result = await client.query(`
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
        `);
        
        if (result.rows.length === 0) {
            console.log('📦 No tables found, importing schema...');
            
            // Čitaj schema.sql
            const schemaPath = path.join(process.cwd(), 'database', 'schema.sql');
            if (fs.existsSync(schemaPath)) {
                const schemaSQL = fs.readFileSync(schemaPath, 'utf8');
                console.log('📄 Importing schema.sql...');
                await client.query(schemaSQL);
                console.log('✅ Schema imported successfully!');
            } else {
                console.log('❌ schema.sql not found at:', schemaPath);
                // Kreiraj basic schema
                await createBasicSchema(client);
            }
        } else {
            console.log(`✅ Database already has ${result.rows.length} tables`);
        }
        
        client.release();
    } catch (error) {
        console.error('❌ Database init error:', error.message);
    } finally {
        await pool.end();
    }
}

async function createBasicSchema(client) {
    console.log('🔨 Creating basic schema...');
    
    const basicSQL = `
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            email VARCHAR(255) UNIQUE NOT NULL,
            password VARCHAR(255) NOT NULL,
            name VARCHAR(255),
            created_at TIMESTAMP DEFAULT NOW()
        );

        CREATE TABLE IF NOT EXISTS clients (
            id SERIAL PRIMARY KEY,
            name VARCHAR(255) NOT NULL,
            email VARCHAR(255),
            company VARCHAR(255),
            owner_id INTEGER REFERENCES users(id),
            created_at TIMESTAMP DEFAULT NOW()
        );

        CREATE TABLE IF NOT EXISTS notes (
            id SERIAL PRIMARY KEY,
            content TEXT NOT NULL,
            client_id INTEGER REFERENCES clients(id) ON DELETE CASCADE,
            created_at TIMESTAMP DEFAULT NOW()
        );

        INSERT INTO users (email, password, name) 
        VALUES ('demo@demo.com', 'demo123', 'Demo User')
        ON CONFLICT (email) DO NOTHING;
    `;
    
    await client.query(basicSQL);
    console.log('✅ Basic schema created with demo user');
}

// Pokreni database init
initializeDatabase();

// ⭐⭐⭐ KRAJ DATABASE INIT ⭐⭐⭐

// Ostali kod ide ovdje...
app.use(cors());
app.use(express.json());

app.get('/', (req, res) => {
    res.json({ message: 'CRM API is running!' });
});

/ Osnovni endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: 'CRM Backend API is running!',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development'
  });
});

// Health check
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ 
      status: 'OK', 
      database: 'connected',
      timestamp: new Date().toISOString(),
      environment: process.env.NODE_ENV || 'development'
    });
  } catch (error) {
    console.error('Health check failed:', error.message);
    res.status(500).json({ 
      status: 'ERROR', 
      database: 'disconnected',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Debug endpoint za provjeru stanja baze
app.get('/api/debug/database', async (req, res) => {
  try {
    console.log('🔍 Debug database check...');
    
    const client = await pool.connect();
    
    const tablesResult = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public'
      ORDER BY table_name
    `);

    const tableCounts = {};
    const tableData = {};
    
    for (let table of tablesResult.rows) {
      const tableName = table.table_name;
      
      // Broj redova
      const countResult = await client.query(`SELECT COUNT(*) as count FROM ${tableName}`);
      tableCounts[tableName] = parseInt(countResult.rows[0].count);
      
      // Prvih 5 redova (ako postoje)
      if (tableCounts[tableName] > 0) {
        const dataResult = await client.query(`SELECT * FROM ${tableName} LIMIT 3`);
        tableData[tableName] = dataResult.rows;
      } else {
        tableData[tableName] = [];
      }
    }

    client.release();

    const debugInfo = {
      tables: tablesResult.rows.map(row => row.table_name),
      counts: tableCounts,
      sampleData: tableData,
      connection: 'successful',
      timestamp: new Date().toISOString(),
      environment: process.env.NODE_ENV || 'development'
    };

    console.log('📊 Debug info:', debugInfo);
    res.json(debugInfo);

  } catch (error) {
    console.error('❌ Debug database error:', error);
    res.status(500).json({
      error: error.message,
      connection: 'failed',
      timestamp: new Date().toISOString()
    });
  }
});

// Stats endpoint
app.get('/api/clients/stats', async (req, res) => {
  try {
    console.log('📊 Getting stats...');
    
    const clientsResult = await pool.query('SELECT COUNT(*) as count FROM clients');
    const notesResult = await pool.query('SELECT COUNT(*) as count FROM notes');
    const lastNoteResult = await pool.query(
      'SELECT content FROM notes ORDER BY created_at DESC LIMIT 1'
    );

    const stats = {
      clients: parseInt(clientsResult.rows[0].count),
      totalNotes: parseInt(notesResult.rows[0].count),
      lastNote: lastNoteResult.rows[0]?.content || 'Nema bilježki'
    };

    console.log('📈 Stats calculated:', stats);
    res.json(stats);
  } catch (error) {
    console.error('❌ Get stats error:', error);
    res.status(500).json({ 
      error: 'Database error',
      details: error.message 
    });
  }
});

// Login endpoint
app.post('/api/login', async (req, res) => {
  const { email, password } = req.body;

  console.log('🔐 Login attempt for:', email);

  try {
    const result = await pool.query(
      'SELECT * FROM users WHERE email = $1',
      [email]
    );

    const user = result.rows[0];
    
    if (!user) {
      console.log('❌ User not found:', email);
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Plain text provjera - jednostavno za demo
    if (password === user.password) {
      console.log('✅ Login successful for:', email);
      
      const token = 'demo-token-' + Date.now();
      
      res.json({ 
        token, 
        user: { 
          id: user.id, 
          email: user.email, 
          name: user.name 
        } 
      });
    } else {
      console.log('❌ Password mismatch for:', email);
      return res.status(401).json({ error: 'Invalid credentials' });
    }
  } catch (error) {
    console.error('💥 Login error:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

// Clients endpoints
app.get('/api/clients', async (req, res) => {
  try {
    console.log('📋 Getting clients list...');
    
    const result = await pool.query('SELECT * FROM clients ORDER BY created_at DESC');
    
    console.log(`✅ Found ${result.rows.length} clients`);
    res.json(result.rows);
    
  } catch (error) {
    console.error('❌ Get clients error:', error.message);
    
    res.status(500).json({ 
      error: 'Database error',
      message: error.message,
      details: 'Check if database is running and tables exist'
    });
  }
});

app.post('/api/clients', async (req, res) => {
  const { name, email, company } = req.body;

  console.log('➕ Creating new client:', name);

  try {
    // Uzmi prvog usera kao owner_id
    const userResult = await pool.query('SELECT id FROM users LIMIT 1');
    const ownerId = userResult.rows[0]?.id;

    if (!ownerId) {
      return res.status(400).json({ error: 'No user found' });
    }

    const result = await pool.query(
      `INSERT INTO clients (name, email, company, owner_id) 
       VALUES ($1, $2, $3, $4) 
       RETURNING *`,
      [name, email, company || name, ownerId]
    );
    
    console.log('✅ Client created:', result.rows[0].name);
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Create client error:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

app.delete('/api/clients/:id', async (req, res) => {
  const { id } = req.params;

  console.log('🗑️ Deleting client:', id);

  try {
    const result = await pool.query(
      'DELETE FROM clients WHERE id = $1 RETURNING *',
      [id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Client not found' });
    }
    
    console.log('✅ Client deleted:', result.rows[0].name);
    res.json({ message: 'Client deleted', client: result.rows[0] });
  } catch (error) {
    console.error('Delete client error:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

// Notes endpoints
app.get('/api/clients/:id/notes', async (req, res) => {
  const { id } = req.params;

  console.log('📝 Getting notes for client:', id);

  try {
    const result = await pool.query(
      `SELECT * FROM notes WHERE client_id = $1 ORDER BY created_at DESC`,
      [id]
    );
    
    console.log('📋 Notes found:', result.rows.length);
    res.json(result.rows);
  } catch (error) {
    console.error('Get notes error:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

app.post('/api/clients/:id/notes', async (req, res) => {
  const { id } = req.params;
  const { content } = req.body;

  console.log('➕ Adding note for client:', id, 'Content:', content);

  if (!content || content.trim() === '') {
    return res.status(400).json({ error: 'Note content is required' });
  }

  try {
    // Provjeri da klijent postoji
    const clientCheck = await pool.query(
      'SELECT id FROM clients WHERE id = $1',
      [id]
    );

    if (clientCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Client not found' });
    }

    const result = await pool.query(
      `INSERT INTO notes (content, client_id) 
       VALUES ($1, $2) 
       RETURNING *`,
      [content.trim(), id]
    );
    
    console.log('✅ Note added successfully');
    res.json(result.rows[0]);
  } catch (error) {
    console.error('💥 Add note error:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

// DELETE endpoint za brisanje bilješki
app.delete('/api/notes/:id', async (req, res) => {
  const { id } = req.params;

  console.log('🗑️ Deleting note:', id);

  try {
    const result = await pool.query(
      'DELETE FROM notes WHERE id = $1 RETURNING *',
      [id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Bilješka nije pronađena' });
    }
    
    console.log('✅ Note deleted:', result.rows[0].id);
    res.json({ 
      message: 'Bilješka uspješno obrisana', 
      note: result.rows[0] 
    });
  } catch (error) {
    console.error('Delete note error:', error);
    res.status(500).json({ error: 'Greška pri brisanju bilješke' });
  }
});

// Novi endpoint za dobivanje broja bilješki po klijentu
app.get('/api/clients/notes-count', async (req, res) => {
  try {
    console.log('📊 Getting notes count per client...');
    
    const result = await pool.query(`
      SELECT 
        c.id as client_id,
        c.name as client_name,
        COUNT(n.id) as notes_count
      FROM clients c
      LEFT JOIN notes n ON c.id = n.client_id
      GROUP BY c.id, c.name
      ORDER BY c.name
    `);

    const notesCount = {};
    result.rows.forEach(row => {
      notesCount[row.client_id] = {
        count: parseInt(row.notes_count),
        name: row.client_name
      };
    });

    console.log('✅ Notes count per client:', notesCount);
    res.json(notesCount);
  } catch (error) {
    console.error('❌ Get notes count error:', error);
    res.status(500).json({ 
      error: 'Database error',
      details: error.message 
    });
  }
});

// Start server
app.listen(PORT, async () => {
  console.log(`🚀 Backend server running on port: ${PORT}`);
  console.log(`🌐 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`📊 PostgreSQL database: ${process.env.DATABASE_URL ? 'Railway' : 'Local'}`);
  console.log(`🔐 Demo login: demo@demo.com / demo123`);
  console.log(`🐛 Debug endpoint: http://localhost:${PORT}/api/debug/database`);
  
  if (process.env.NODE_ENV === 'production') {
    console.log(`🔗 Frontend URL: https://crm-stgaing-app.vercel.app`);
  }
  
  // Testiraj konekciju pri pokretanju
  const dbConnected = await testDatabaseConnection();
  if (!dbConnected) {
    console.log('❌ WARNING: Cannot connect to database!');
  }
});