import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import cors from 'cors';
import pkg from 'pg';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';

const { Pool } = pkg;

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 8888;
const JWT_SECRET = process.env.JWT_SECRET || 'your_jwt_secret_key_here_change_in_production';

// Database configuration za Upsun
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  connectionTimeoutMillis: 10000,
  idleTimeoutMillis: 30000,
  max: 20
});

// CORS konfiguracija za Upsun
const allowedOrigins = [
  'https://staging-5em2ouy-ndb75vqywwrn6.eu-5.platformsh.site',
  'https://*.platformsh.site',
  'http://localhost:5173',
  'http://localhost:3000'
];

app.use(cors({
  origin: function (origin, callback) {
    if (!origin) return callback(null, true);
    
    if (allowedOrigins.some(allowed => {
      if (allowed.includes('*')) {
        return origin.endsWith(allowed.split('*')[1]);
      }
      return allowed === origin;
    })) {
      return callback(null, true);
    } else {
      console.log('CORS blocked for origin:', origin);
      return callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true
}));

app.use(express.json());

// **KLJUČNO ZA UPSUN: Serviranje statičkih fajlova iz frontend dist**
app.use(express.static(path.join(__dirname, '../frontend/dist')));

// JWT Authentication Middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  });
};

// Database health check
async function checkDatabaseSetup() {
  try {
    const client = await pool.connect();
    
    const usersCheck = await client.query('SELECT COUNT(*) as count FROM users');
    const clientsCheck = await client.query('SELECT COUNT(*) as count FROM clients');
    const tablesCheck = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public'
      AND table_name IN ('users', 'clients', 'notes', 'activities')
    `);
    
    client.release();
    
    const status = {
      users: parseInt(usersCheck.rows[0].count),
      clients: parseInt(clientsCheck.rows[0].count),
      tables: tablesCheck.rows.map(row => row.table_name),
      allTablesExist: tablesCheck.rows.length === 4
    };
    
    console.log('📊 Database status:', status);
    return status;
  } catch (error) {
    console.error('❌ Database setup check failed:', error.message);
    return { error: error.message };
  }
}

// **MIDDLEWARE ZA /api RUTE**
app.use('/api', (req, res, next) => {
  console.log(`📨 API Request: ${req.method} ${req.path}`);
  next();
});

// Osnovni endpoint
app.get('/api', (req, res) => {
  res.json({ 
    message: 'CRM Backend API is running!',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString(),
    platform: 'Upsun'
  });
});

// Health check s detaljima o bazi
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    
    const dbStatus = await checkDatabaseSetup();
    
    res.json({ 
      status: dbStatus.allTablesExist ? 'OK' : 'DEGRADED',
      environment: process.env.NODE_ENV || 'development',
      database: 'connected',
      platform: 'Upsun',
      tables: dbStatus.tables,
      stats: {
        users: dbStatus.users || 0,
        clients: dbStatus.clients || 0
      }
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

// AUTH ENDPOINTS
app.post('/api/auth/login', async (req, res) => {
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

    const validPassword = await bcrypt.compare(password, user.password_hash);
    if (!validPassword) {
      console.log('❌ Password mismatch for:', email);
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    console.log('✅ Login successful for:', email);
    
    const token = jwt.sign(
      { 
        id: user.id, 
        username: user.username, 
        email: user.email,
        role: user.role 
      },
      JWT_SECRET,
      { expiresIn: '24h' }
    );
    
    res.json({ 
      message: 'Login successful',
      token,
      user: { 
        id: user.id,
        username: user.username,
        email: user.email,
        firstName: user.first_name,
        lastName: user.last_name,
        role: user.role
      }
    });
  } catch (error) {
    console.error('💥 Login error:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

// Registracija endpoint
app.post('/api/auth/register', async (req, res) => {
  const { username, email, password, firstName, lastName } = req.body;

  console.log('👤 Registration attempt:', { 
    username, 
    email, 
    hasPassword: !!password,
    firstName, 
    lastName 
  });

  try {
    if (!username || !email || !password) {
      console.log('❌ Missing required fields');
      return res.status(400).json({ 
        error: 'Username, email and password are required',
        received: { username: !!username, email: !!email, password: !!password }
      });
    }

    if (password.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters long' });
    }

    // Provjeri postoji li korisnik
    console.log('🔍 Checking for existing user...');
    const existingUsers = await pool.query(
      'SELECT id FROM users WHERE email = $1 OR username = $2',
      [email, username]
    );

    console.log('📊 Existing users found:', existingUsers.rows.length);

    if (existingUsers.rows.length > 0) {
      console.log('❌ User already exists');
      return res.status(400).json({ error: 'User with this email or username already exists' });
    }

    // Hash password
    console.log('🔒 Hashing password...');
    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(password, saltRounds);

    // Kreiraj korisnika
    console.log('💾 Creating user in database...');
    const result = await pool.query(
      'INSERT INTO users (username, email, password_hash, first_name, last_name) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [username, email, passwordHash, firstName, lastName]
    );

    const user = result.rows[0];
    console.log('✅ User created successfully:', { id: user.id, email: user.email });
    
    // Generiraj token
    const token = jwt.sign(
      { 
        id: user.id, 
        username: user.username, 
        email: user.email,
        role: user.role 
      },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    console.log('✅ User registered successfully');

    res.status(201).json({
      message: 'User registered successfully',
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        firstName: user.first_name,
        lastName: user.last_name,
        role: user.role
      }
    });

  } catch (error) {
    console.error('💥 Registration error:', {
      message: error.message,
      code: error.code,
      detail: error.detail
    });
    
    if (error.code === '23505') {
      return res.status(400).json({ error: 'User with this email or username already exists' });
    }
    
    if (error.code === '23502') {
      return res.status(400).json({ error: 'Required field is missing' });
    }
    
    res.status(500).json({ 
      error: 'Database error',
      details: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
    });
  }
});

// Profil endpoint
app.get('/api/auth/profile', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;

    const result = await pool.query(
      'SELECT id, username, email, first_name, last_name, role, created_at FROM users WHERE id = $1',
      [userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ user: result.rows[0] });

  } catch (error) {
    console.error('💥 Profile error:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

// Clients endpoints
app.get('/api/clients', authenticateToken, async (req, res) => {
  try {
    console.log('📋 Getting clients list...');
    
    const result = await pool.query(`
      SELECT c.*, u.username as created_by_username 
      FROM clients c 
      LEFT JOIN users u ON c.created_by = u.id 
      ORDER BY c.created_at DESC
    `);
    
    console.log(`✅ Found ${result.rows.length} clients`);
    res.json(result.rows);
    
  } catch (error) {
    console.error('❌ Get clients error:', error.message);
    res.status(500).json({ error: 'Database error' });
  }
});

app.post('/api/clients', authenticateToken, async (req, res) => {
  const { name, email, company, phone, address } = req.body;

  console.log('➕ Creating new client:', name);

  try {
    const result = await pool.query(
      `INSERT INTO clients (name, email, company, phone, address, created_by) 
       VALUES ($1, $2, $3, $4, $5, $6) 
       RETURNING *`,
      [name, email, company || null, phone || null, address || null, req.user.id]
    );
    
    console.log('✅ Client created:', result.rows[0].name);
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Create client error:', error);
    
    if (error.code === '23505') {
      return res.status(400).json({ error: 'Client with this email already exists' });
    }
    
    res.status(500).json({ error: 'Database error' });
  }
});

// Notes endpoints
app.get('/api/clients/:id/notes', authenticateToken, async (req, res) => {
  const { id } = req.params;

  console.log('📝 Getting notes for client:', id);

  try {
    const result = await pool.query(
      `SELECT n.*, u.username as created_by_username 
       FROM notes n 
       LEFT JOIN users u ON n.created_by = u.id 
       WHERE client_id = $1 
       ORDER BY n.created_at DESC`,
      [id]
    );
    
    console.log('📋 Notes found:', result.rows.length);
    res.json(result.rows);
  } catch (error) {
    console.error('Get notes error:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

app.post('/api/clients/:id/notes', authenticateToken, async (req, res) => {
  const { id } = req.params;
  const { content } = req.body;

  console.log('➕ Adding note for client:', id, 'Content:', content);

  if (!content || content.trim() === '') {
    return res.status(400).json({ error: 'Note content is required' });
  }

  try {
    const result = await pool.query(
      `INSERT INTO notes (content, client_id, created_by) 
       VALUES ($1, $2, $3) 
       RETURNING *`,
      [content.trim(), id, req.user.id]
    );
    
    console.log('✅ Note added successfully');
    res.json(result.rows[0]);
  } catch (error) {
    console.error('💥 Add note error:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

// GET /api/clients/notes-count
app.get('/api/clients/notes-count', authenticateToken, async (req, res) => {
  try {
    console.log('📊 Getting notes count per client...');
    
    const result = await pool.query(`
      SELECT 
        c.id,
        c.name,
        COUNT(n.id) as count
      FROM clients c
      LEFT JOIN notes n ON c.id = n.client_id
      GROUP BY c.id, c.name
      ORDER BY c.name
    `);
    
    console.log(`✅ Found notes count for ${result.rows.length} clients`);
    
    const notesCount = {};
    result.rows.forEach(row => {
      notesCount[row.id] = {
        count: parseInt(row.count),
        name: row.name
      };
    });
    
    res.json(notesCount);
    
  } catch (error) {
    console.error('❌ Get notes count error:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

// GET /api/clients/stats
app.get('/api/clients/stats', authenticateToken, async (req, res) => {
  try {
    console.log('📈 Getting client statistics...');
    
    const clientsResult = await pool.query('SELECT COUNT(*) as count FROM clients');
    const totalClients = parseInt(clientsResult.rows[0].count);
    
    const withNotesResult = await pool.query(`
      SELECT COUNT(DISTINCT c.id) as count
      FROM clients c
      INNER JOIN notes n ON c.id = n.client_id
    `);
    const clientsWithNotes = parseInt(withNotesResult.rows[0].count);
    
    const notesResult = await pool.query('SELECT COUNT(*) as count FROM notes');
    const totalNotes = parseInt(notesResult.rows[0].count);
    
    const stats = {
      totalClients: totalClients,
      clientsWithNotes: clientsWithNotes,
      clientsWithoutNotes: totalClients - clientsWithNotes,
      totalNotes: totalNotes,
      averageNotesPerClient: totalClients > 0 ? (totalNotes / totalClients).toFixed(2) : '0.00'
    };
    
    console.log('📊 Stats calculated:', stats);
    res.json(stats);
    
  } catch (error) {
    console.error('❌ Get stats error:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

// GET /api/notes
app.get('/api/notes', authenticateToken, async (req, res) => {
  try {
    console.log('📝 Getting all notes...');
    
    const result = await pool.query(`
      SELECT n.*, c.name as client_name, u.username as created_by_username
      FROM notes n
      LEFT JOIN clients c ON n.client_id = c.id
      LEFT JOIN users u ON n.created_by = u.id
      ORDER BY n.created_at DESC
    `);
    
    console.log(`✅ Found ${result.rows.length} notes`);
    res.json(result.rows);
    
  } catch (error) {
    console.error('❌ Get notes error:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

// DELETE /api/clients/:id
app.delete('/api/clients/:id', authenticateToken, async (req, res) => {
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

// PUT /api/clients/:id
app.put('/api/clients/:id', authenticateToken, async (req, res) => {
  const { id } = req.params;
  const { name, email, company, phone, address } = req.body;

  console.log('✏️ Updating client:', id);

  try {
    const result = await pool.query(
      `UPDATE clients 
       SET name = $1, email = $2, company = $3, phone = $4, address = $5, updated_at = CURRENT_TIMESTAMP
       WHERE id = $6 
       RETURNING *`,
      [name, email, company, phone, address, id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Client not found' });
    }
    
    console.log('✅ Client updated:', result.rows[0].name);
    res.json(result.rows[0]);
  } catch (error) {
    console.error('❌ Update client error:', error);
    
    if (error.code === '23505') {
      return res.status(400).json({ error: 'Client with this email already exists' });
    }
    
    res.status(500).json({ error: 'Database error' });
  }
});

// DELETE /api/notes/:id
app.delete('/api/notes/:id', authenticateToken, async (req, res) => {
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
app.get('/api/debug/db-check', async (req, res) => {
  try {
    console.log('🔍 Database check...');
    
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
      timestamp: new Date().toISOString(),
      platform: 'Upsun'
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

// **ERROR HANDLING MIDDLEWARE**
app.use((error, req, res, next) => {
  console.error('💥 Global error handler:', error);
  res.status(500).json({ 
    error: 'Internal server error',
    message: error.message 
  });
});

// **404 HANDLER ZA /api RUTE**
app.use('/api', (req, res) => {
  res.status(404).json({ 
    error: 'API endpoint not found',
    path: req.path,
    method: req.method
  });
});

// **KLJUČNO ZA UPSUN: Fallback za Vue Router - OVO MORA BITI ZADNJE**
app.get('*', (req, res) => {
  if (req.path.startsWith('/api/')) {
    return res.status(404).json({ error: 'API route not found' });
  }
  
  res.sendFile(path.join(__dirname, '../frontend/dist/index.html'));
});

// Start server
app.listen(PORT, '0.0.0.0', async () => {
  console.log(`🚀 CRM Backend running on port: ${PORT}`);
  console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🏠 Host: 0.0.0.0`);
  console.log(`🔗 API URL: http://localhost:${PORT}/api`);
  console.log(`🔐 JWT Secret: ${JWT_SECRET === 'your_jwt_secret_key_here_change_in_production' ? 'DEFAULT (change in production!)' : 'CUSTOM'}`);
  console.log(`📁 Current directory: ${process.cwd()}`);
  console.log(`📁 Backend directory: ${__dirname}`);
  
  // Provjeri database setup
  const dbStatus = await checkDatabaseSetup();
  if (dbStatus.allTablesExist) {
    console.log('✅ Database is ready');
    console.log('👤 Demo users available (see init.js for credentials)');
  } else {
    console.warn('⚠️ Database may not be properly initialized');
  }
});