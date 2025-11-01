// server.js
import cors from 'cors';
import express from 'express';
import pkg from 'pg';
const { Pool } = pkg;
import fs from 'fs';
import path from 'path';

const app = express();
const PORT = process.env.PORT || 3001;

// ⭐⭐⭐ GLOBALNI DATABASE POOL ⭐⭐⭐
const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false }
});

// Error handling za pool
pool.on('error', (err) => {
    console.error('💥 Database pool error:', err);
});

// ⭐⭐⭐ CORS MIDDLEWARE ⭐⭐⭐
app.use(cors({
  origin: [
    'https://crm-basic-9r093y1se-denis-projects-e03958c1.vercel.app',
    'https://crm-stgaing-app.vercel.app',
    'https://crm-staging-app.vercel.app',
    'http://localhost:5173',
    'http://localhost:3000'
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
}));

// Explicit preflight handling
app.options('*', (req, res) => {
  res.header('Access-Control-Allow-Origin', req.headers.origin);
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.header('Access-Control-Allow-Credentials', 'true');
  res.status(204).send();
});

app.use(express.json());
app.options('*', cors());

// ⭐⭐⭐ POBOLJŠANI DATABASE INIT ⭐⭐⭐
async function initializeDatabase() {
    console.log('🔧 Starting database initialization...');
    
    let client;
    try {
        client = await pool.connect();
        console.log('✅ Database connected');

        // Korak 1: Provjeri postoje li tabele
        const tablesResult = await client.query(`
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
            AND table_name IN ('users', 'clients', 'notes')
        `);
        
        const foundTables = tablesResult.rows.map(row => row.table_name);
        console.log('📊 Found tables:', foundTables);

        // Korak 2: Kreiraj tabele ako nedostaju
        if (foundTables.length < 3) {
            console.log('📦 Creating missing tables...');
            await createTables(client);
        }

        // Korak 3: UVJEK dodaj demo podatke
        console.log('🌱 Seeding demo data...');
        await seedDemoData(client);
        
        console.log('🎉 Database initialization completed!');
        
    } catch (error) {
        console.error('❌ Database init error:', error.message);
    } finally {
        if (client) client.release();
    }
}

async function createTables(client) {
    const tablesSQL = `
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            email VARCHAR(255) UNIQUE NOT NULL,
            password VARCHAR(255) NOT NULL,
            name VARCHAR(255) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS clients (
            id SERIAL PRIMARY KEY,
            name VARCHAR(255) NOT NULL,
            email VARCHAR(255) NOT NULL,
            company VARCHAR(255),
            owner_id INTEGER REFERENCES users(id),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS notes (
            id SERIAL PRIMARY KEY,
            content TEXT NOT NULL,
            client_id INTEGER REFERENCES clients(id) ON DELETE CASCADE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    `;
    
    await client.query(tablesSQL);
    console.log('✅ Tables created successfully');
}

async function seedDemoData(client) {
    try {
        // 1. UVJEK kreiraj/update demo usera
        await client.query(`
            INSERT INTO users (email, password, name) 
            VALUES ('demo@demo.com', 'demo123', 'Demo User')
            ON CONFLICT (email) DO UPDATE SET
            password = EXCLUDED.password,
            name = EXCLUDED.name
        `);
        console.log('✅ Demo user: demo@demo.com / demo123');

        // 2. Dohvati user ID
        const userResult = await client.query('SELECT id FROM users WHERE email = $1', ['demo@demo.com']);
        const userId = userResult.rows[0].id;

        // 3. Dodaj demo klijente
        await client.query(`
            INSERT INTO clients (name, email, company, owner_id) 
            VALUES 
                ('Tech Company d.o.o.', 'tech@company.com', 'Tech Company', $1),
                ('Marketing Agency', 'info@marketing.com', 'Marketing Pros', $1),
                ('Startup XYZ', 'hello@startup.com', 'Startup XYZ', $1)
            ON CONFLICT DO NOTHING
        `, [userId]);
        console.log('✅ Demo clients added');

        // 4. Dohvati client IDs i dodaj bilješke
        const clientsResult = await client.query('SELECT id FROM clients ORDER BY id LIMIT 3');
        if (clientsResult.rows.length > 0) {
            await client.query(`
                INSERT INTO notes (content, client_id) 
                VALUES 
                    ('Prvi kontakt - zainteresirani za naš proizvod', $1),
                    ('Slanje ponude u ponedjeljak', $1),
                    ('Klijent zadovoljan demo verzijom', $2),
                    ('Potrebno dogovoriti sastanak sljedeći tjedan', $3)
                ON CONFLICT DO NOTHING
            `, [clientsResult.rows[0].id, clientsResult.rows[1].id, clientsResult.rows[2].id]);
            console.log('✅ Demo notes added');
        }

    } catch (error) {
        console.error('❌ Demo data seeding error:', error.message);
    }
}

// ⭐⭐⭐ FORCE SEED ENDPOINT ⭐⭐⭐
app.post('/api/force-seed', async (req, res) => {
    console.log('🔄 FORCE SEEDING DATABASE...');
    
    let client;
    try {
        client = await pool.connect();

        // 1. Obriši sve postojeće podatke
        await client.query('DELETE FROM notes');
        await client.query('DELETE FROM clients');
        await client.query('DELETE FROM users');
        console.log('✅ Cleared existing data');

        // 2. Kreiraj tabele
        await createTables(client);

        // 3. Dodaj demo podatke
        await seedDemoData(client);

        // 4. Provjeri rezultat
        const usersCount = await client.query('SELECT COUNT(*) as count FROM users');
        const clientsCount = await client.query('SELECT COUNT(*) as count FROM clients');
        const notesCount = await client.query('SELECT COUNT(*) as count FROM notes');

        res.json({ 
            success: true,
            message: 'Database force-seeded successfully!',
            counts: {
                users: parseInt(usersCount.rows[0].count),
                clients: parseInt(clientsCount.rows[0].count),
                notes: parseInt(notesCount.rows[0].count)
            }
        });

    } catch (error) {
        console.error('💥 Force seed error:', error);
        res.status(500).json({ 
            success: false,
            error: error.message
        });
    } finally {
        if (client) client.release();
    }
});

// ⭐⭐⭐ COMPREHENSIVE DEBUG ENDPOINT ⭐⭐⭐
app.get('/api/debug/full', async (req, res) => {
    let client;
    try {
        client = await pool.connect();
        
        const usersResult = await client.query('SELECT * FROM users');
        const clientsResult = await client.query('SELECT * FROM clients');
        const notesResult = await client.query('SELECT * FROM notes');
        
        const countsResult = await client.query(`
            SELECT 
                (SELECT COUNT(*) FROM users) as users_count,
                (SELECT COUNT(*) FROM clients) as clients_count,
                (SELECT COUNT(*) FROM notes) as notes_count
        `);

        const debugInfo = {
            success: true,
            users: {
                count: usersResult.rows.length,
                data: usersResult.rows
            },
            clients: {
                count: clientsResult.rows.length,
                data: clientsResult.rows
            },
            notes: {
                count: notesResult.rows.length,
                data: notesResult.rows
            },
            totals: countsResult.rows[0],
            timestamp: new Date().toISOString()
        };

        console.log('🔍 FULL DEBUG INFO:', debugInfo.totals);
        res.json(debugInfo);

    } catch (error) {
        console.error('Full debug error:', error);
        res.status(500).json({ 
            success: false,
            error: error.message
        });
    } finally {
        if (client) client.release();
    }
});

// ⭐⭐⭐ HEALTH CHECK ⭐⭐⭐
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

// ⭐⭐⭐ BASIC DEBUG ENDPOINT ⭐⭐⭐
app.get('/api/debug/database', async (req, res) => {
    let client;
    try {
        client = await pool.connect();
        
        const tablesResult = await client.query(`
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
            ORDER BY table_name
        `);

        const tableCounts = {};
        for (let table of tablesResult.rows) {
            const tableName = table.table_name;
            const countResult = await client.query(`SELECT COUNT(*) as count FROM ${tableName}`);
            tableCounts[tableName] = parseInt(countResult.rows[0].count);
        }

        const debugInfo = {
            tables: tablesResult.rows.map(row => row.table_name),
            counts: tableCounts,
            connection: 'successful',
            timestamp: new Date().toISOString()
        };

        res.json(debugInfo);

    } catch (error) {
        console.error('Debug database error:', error);
        res.status(500).json({
            error: error.message,
            connection: 'failed'
        });
    } finally {
        if (client) client.release();
    }
});

// ⭐⭐⭐ ROOT ENDPOINT ⭐⭐⭐
app.get('/', (req, res) => {
    res.json({ 
        message: 'CRM Backend API is running!',
        timestamp: new Date().toISOString(),
        environment: process.env.NODE_ENV || 'development',
        endpoints: {
            health: '/api/health',
            debug: '/api/debug/full',
            forceSeed: 'POST /api/force-seed',
            login: 'POST /api/login'
        }
    });
});

// ⭐⭐⭐ AUTH ENDPOINTS ⭐⭐⭐
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

        if (password === user.password) {
            console.log('✅ Login successful for:', email);
            
            const token = 'demo-token-' + Date.now();
            
            res.json({ 
                success: true,
                token, 
                user: { 
                    id: user.id, 
                    email: user.email, 
                    name: user.name 
                } 
            });
        } else {
            console.log('❌ Password mismatch for:', email);
            return res.status(401).json({ success: false, error: 'Invalid credentials' });
        }
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ success: false, error: 'Database error' });
    }
});

// ⭐⭐⭐ CLIENTS ENDPOINTS ⭐⭐⭐
app.get('/api/clients', async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM clients ORDER BY created_at DESC');
        res.json(result.rows);
    } catch (error) {
        console.error('Get clients error:', error.message);
        res.status(500).json({ error: 'Database error' });
    }
});

app.post('/api/clients', async (req, res) => {
    const { name, email, company } = req.body;
    console.log('➕ Creating new client:', name);

    try {
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
        
        res.json({ message: 'Client deleted', client: result.rows[0] });
    } catch (error) {
        console.error('Delete client error:', error);
        res.status(500).json({ error: 'Database error' });
    }
});

// ⭐⭐⭐ NOTES ENDPOINTS ⭐⭐⭐
app.get('/api/clients/:id/notes', async (req, res) => {
    const { id } = req.params;

    try {
        const result = await pool.query(
            `SELECT * FROM notes WHERE client_id = $1 ORDER BY created_at DESC`,
            [id]
        );
        
        res.json(result.rows);
    } catch (error) {
        console.error('Get notes error:', error);
        res.status(500).json({ error: 'Database error' });
    }
});

app.post('/api/clients/:id/notes', async (req, res) => {
    const { id } = req.params;
    const { content } = req.body;

    if (!content || content.trim() === '') {
        return res.status(400).json({ error: 'Note content is required' });
    }

    try {
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
        
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Add note error:', error);
        res.status(500).json({ error: 'Database error' });
    }
});

app.delete('/api/notes/:id', async (req, res) => {
    const { id } = req.params;

    try {
        const result = await pool.query(
            'DELETE FROM notes WHERE id = $1 RETURNING *',
            [id]
        );
        
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Bilješka nije pronađena' });
        }
        
        res.json({ 
            message: 'Bilješka uspješno obrisana', 
            note: result.rows[0] 
        });
    } catch (error) {
        console.error('Delete note error:', error);
        res.status(500).json({ error: 'Greška pri brisanju bilješke' });
    }
});

// ⭐⭐⭐ STATS ENDPOINTS ⭐⭐⭐
app.get('/api/clients/stats', async (req, res) => {
    try {
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

        res.json(stats);
    } catch (error) {
        console.error('Get stats error:', error);
        res.status(500).json({ error: 'Database error' });
    }
});

app.get('/api/clients/notes-count', async (req, res) => {
    try {
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

        res.json(notesCount);
    } catch (error) {
        console.error('Get notes count error:', error);
        res.status(500).json({ error: 'Database error' });
    }
});

// ⭐⭐⭐ SERVER START SA DATABASE INIT ⭐⭐⭐
const startServer = async () => {
    console.log('🚀 Starting server with database initialization...');
    
    // Pričekaj da se baza inicijalizira
    await initializeDatabase();
    
    // Provjeri stanje baze
    await checkDatabaseStatus();
    
    app.listen(PORT, () => {
        console.log(`✅ Backend server running on port: ${PORT}`);
        console.log(`🌐 Environment: ${process.env.NODE_ENV || 'development'}`);
        console.log(`📊 PostgreSQL database: ${process.env.DATABASE_URL ? 'Railway' : 'Local'}`);
        console.log(`🔐 Demo login: demo@demo.com / demo123`);
        console.log(`🐛 Debug: /api/debug/full`);
        console.log(`🔄 Force seed: POST /api/force-seed`);
        
        if (process.env.NODE_ENV === 'production') {
            console.log(`🔗 Frontend: https://crm-stgaing-app.vercel.app`);
        }
    });
};

async function checkDatabaseStatus() {
    try {
        const client = await pool.connect();
        const usersCount = await client.query('SELECT COUNT(*) as count FROM users');
        const clientsCount = await client.query('SELECT COUNT(*) as count FROM clients');
        const notesCount = await client.query('SELECT COUNT(*) as count FROM notes');
        client.release();
        
        console.log('📊 Final database status:');
        console.log(`   👤 Users: ${parseInt(usersCount.rows[0].count)}`);
        console.log(`   👥 Clients: ${parseInt(clientsCount.rows[0].count)}`);
        console.log(`   📝 Notes: ${parseInt(notesCount.rows[0].count)}`);
        
    } catch (error) {
        console.error('❌ Database status check failed:', error.message);
    }
}

// Pokreni server
startServer().catch(error => {
    console.error('💥 Failed to start server:', error);
    process.exit(1);
});