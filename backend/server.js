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

// CORS konfiguracija za Upsun
app.use(cors({
  origin: [
    'https://staging-5em2ouy-ndb75vqywwrn6.eu-5.platformsh.site',
    'http://localhost:5173'
  ],
  credentials: true
}));
app.use(express.json());

// Test konekcije na bazu
async function testDatabaseConnection() {
  try {
    const client = await pool.connect();
    console.log('✅ Database connection successful');
    client.release();
    return true;
  } catch (error) {
    console.error('❌ Database connection failed:', error.message);
    return false;
  }
}

// **DODAJTE OVAJ MIDDLEWARE ZA /api RUTE**
app.use('/api', (req, res, next) => {
  console.log(`📨 API Request: ${req.method} ${req.path}`);
  next();
});

// Osnovni endpoint - OVO JE VAŽNO ZA /api/
app.get('/api', (req, res) => {
  res.json({ 
    message: 'CRM Backend API is running!',
    environment: process.env.NODE_ENV || 'development',
    database: 'connected',
    timestamp: new Date().toISOString()
  });
});

// Health check
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ 
      status: 'OK', 
      environment: process.env.NODE_ENV || 'development',
      database: 'connected'
    });
  } catch (error) {
    res.status(500).json({ 
      status: 'ERROR',
      environment: process.env.NODE_ENV || 'development',
      database: 'error',
      error: error.message
    });
  }
});

// LOGIN ENDPOINT
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
    res.status(500).json({ error: 'Database error' });
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

// DODAJTE OVE NOVE ENDPOINT-E:

// GET /api/clients/notes-count - broj bilješki po klijentu
app.get('/api/clients/notes-count', async (req, res) => {
  try {
    console.log('📊 Getting notes count per client...');
    
    const result = await pool.query(`
      SELECT 
        c.id,
        c.name,
        COUNT(n.id) as notes_count
      FROM clients c
      LEFT JOIN notes n ON c.id = n.client_id
      GROUP BY c.id, c.name
      ORDER BY c.name
    `);
    
    console.log(`✅ Found notes count for ${result.rows.length} clients`);
    
    const notesCount = result.rows.map(row => ({
      clientId: row.id,
      name: row.name,
      notesCount: parseInt(row.notes_count)
    }));
    
    res.json(notesCount);
    
  } catch (error) {
    console.error('❌ Get notes count error:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

// GET /api/clients/stats - detaljna statistika klijenata
app.get('/api/clients/stats', async (req, res) => {
  try {
    console.log('📈 Getting client statistics...');
    
    // Ukupni broj klijenata
    const clientsResult = await pool.query('SELECT COUNT(*) as count FROM clients');
    const totalClients = parseInt(clientsResult.rows[0].count);
    
    // Klijenti s bilješkama
    const withNotesResult = await pool.query(`
      SELECT COUNT(DISTINCT c.id) as count
      FROM clients c
      INNER JOIN notes n ON c.id = n.client_id
    `);
    const clientsWithNotes = parseInt(withNotesResult.rows[0].count);
    
    // Ukupno bilješki
    const notesResult = await pool.query('SELECT COUNT(*) as count FROM notes');
    const totalNotes = parseInt(notesResult.rows[0].count);
    
    const stats = {
      totalClients: totalClients,
      clientsWithNotes: clientsWithNotes,
      clientsWithoutNotes: totalClients - clientsWithNotes,
      totalNotes: totalNotes,
      averageNotesPerClient: totalClients > 0 ? (totalNotes / totalClients).toFixed(2) : 0
    };
    
    console.log('📊 Stats calculated:', stats);
    res.json(stats);
    
  } catch (error) {
    console.error('❌ Get stats error:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

// GET /api/notes - sve bilješke (za fallback)
app.get('/api/notes', async (req, res) => {
  try {
    console.log('📝 Getting all notes...');
    
    const result = await pool.query(`
      SELECT n.*, c.name as client_name 
      FROM notes n
      LEFT JOIN clients c ON n.client_id = c.id
      ORDER BY n.created_at DESC
    `);
    
    console.log(`✅ Found ${result.rows.length} notes`);
    res.json(result.rows);
    
  } catch (error) {
    console.error('❌ Get notes error:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

// DELETE /api/clients/:id - brisanje klijenta
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
    res.json({ message: 'Client deleted successfully', client: result.rows[0] });
  } catch (error) {
    console.error('❌ Delete client error:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

// PUT /api/clients/:id - ažuriranje klijenta
app.put('/api/clients/:id', async (req, res) => {
  const { id } = req.params;
  const { name, email, company } = req.body;

  console.log('✏️ Updating client:', id);

  try {
    const result = await pool.query(
      `UPDATE clients 
       SET name = $1, email = $2, company = $3 
       WHERE id = $4 
       RETURNING *`,
      [name, email, company, id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Client not found' });
    }
    
    console.log('✅ Client updated:', result.rows[0].name);
    res.json(result.rows[0]);
  } catch (error) {
    console.error('❌ Update client error:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

// DELETE /api/notes/:id - brisanje bilješke
app.delete('/api/notes/:id', async (req, res) => {
  const { id } = req.params;

  console.log('🗑️ Deleting note:', id);

  try {
    const result = await pool.query(
      'DELETE FROM notes WHERE id = $1 RETURNING *',
      [id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Note not found' });
    }
    
    console.log('✅ Note deleted');
    res.json({ message: 'Note deleted successfully', note: result.rows[0] });
  } catch (error) {
    console.error('❌ Delete note error:', error);
    res.status(500).json({ error: 'Database error' });
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

    console.log('📊 Debug info:', debugInfo);
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

// **DODAJTE ERROR HANDLING MIDDLEWARE**
app.use((error, req, res, next) => {
  console.error('💥 Global error handler:', error);
  res.status(500).json({ 
    error: 'Internal server error',
    message: error.message 
  });
});

// **DODAJTE 404 HANDLER ZA /api RUTE**
app.use('/api', (req, res) => {
  res.status(404).json({ 
    error: 'API endpoint not found',
    path: req.path,
    method: req.method
  });
});

// Start server
app.listen(PORT, '0.0.0.0', async () => {
  console.log(`🚀 CRM Backend running on port: ${PORT}`);
  console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🔗 API URL: https://staging-5em2ouy-ndb75vqywwrn6.eu-5.platformsh.site/api`);
  console.log(`🔐 Demo login: demo@demo.com / demo123`);
  
  // Testiraj konekciju
  const dbConnected = await testDatabaseConnection();
  if (dbConnected) {
    console.log('✅ Database connection established');
  } else {
    console.log('❌ Database connection failed - check DATABASE_URL');
  }
});