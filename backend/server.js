const express = require('express');
const cors = require('cors');
const { query } = require('./database/db');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json());

// Health check sa database konekcijom
app.get('/api/health', async (req, res) => {
    try {
        // Test database connection
        await query('SELECT NOW()');
        res.json({ 
            status: 'OK', 
            message: 'CRM Backend is running with PostgreSQL',
            database: 'Connected',
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        res.status(500).json({ 
            status: 'ERROR', 
            message: 'Database connection failed',
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// Login sa PostgreSQL
app.post('/api/auth/login', async (req, res) => {
    const { email, password } = req.body;
    
    try {
        // Pronađi usera u bazi
        const result = await query(
            'SELECT id, email, name, password FROM users WHERE email = ',
            [email]
        );
        
        if (result.rows.length === 0) {
            return res.status(401).json({ 
                success: false, 
                message: 'Invalid email or password' 
            });
        }
        
        const user = result.rows[0];
        
        // Za demo svrhe, koristimo jednostavnu provjeru lozinke
        if (password === user.password) {
            return res.json({ 
                success: true, 
                user: { 
                    id: user.id, 
                    email: user.email, 
                    name: user.name 
                },
                token: 'jwt-token-' + user.id
            });
        } else {
            return res.status(401).json({ 
                success: false, 
                message: 'Invalid email or password' 
            });
        }
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Server error during login' 
        });
    }
});

// Get clients iz PostgreSQL
app.get('/api/clients', async (req, res) => {
    try {
        const result = await query('SELECT * FROM clients ORDER BY created_at DESC');
        
        res.json({
            success: true,
            clients: result.rows
        });
    } catch (error) {
        console.error('Get clients error:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Failed to fetch clients' 
        });
    }
});

// Add client u PostgreSQL
app.post('/api/clients', async (req, res) => {
    const { name, email, company, owner_id = 1 } = req.body;
    
    try {
        const result = await query(
            'INSERT INTO clients (name, email, company, owner_id) VALUES (, , , ) RETURNING *',
            [name, email, company, owner_id]
        );
        
        res.json({
            success: true,
            client: result.rows[0]
        });
    } catch (error) {
        console.error('Add client error:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Failed to add client' 
        });
    }
});

// Get client notes iz PostgreSQL
app.get('/api/clients/:id/notes', async (req, res) => {
    const clientId = parseInt(req.params.id);
    
    try {
        const result = await query(
            'SELECT * FROM notes WHERE client_id =  ORDER BY created_at DESC',
            [clientId]
        );
        
        res.json({
            success: true,
            notes: result.rows
        });
    } catch (error) {
        console.error('Get notes error:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Failed to fetch notes' 
        });
    }
});

// Add note u PostgreSQL
app.post('/api/clients/:id/notes', async (req, res) => {
    const clientId = parseInt(req.params.id);
    const { content } = req.body;
    
    try {
        const result = await query(
            'INSERT INTO notes (content, client_id) VALUES (, ) RETURNING *',
            [content, clientId]
        );
        
        res.json({
            success: true,
            note: result.rows[0]
        });
    } catch (error) {
        console.error('Add note error:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Failed to add note' 
        });
    }
});

// Root endpoint
app.get('/', (req, res) => {
    res.json({ 
        message: 'CRM Backend API with PostgreSQL',
        version: '1.0.0',
        endpoints: {
            health: 'GET /api/health',
            login: 'POST /api/auth/login',
            clients: 'GET /api/clients',
            'add-client': 'POST /api/clients',
            'client-notes': 'GET /api/clients/:id/notes',
            'add-note': 'POST /api/clients/:id/notes'
        },
        database: 'PostgreSQL',
        demo: {
            email: 'demo@demo.com',
            password: 'demo123'
        }
    });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log('=================================');
    console.log('🚀 CRM Backend STARTED SUCCESSFULLY');
    console.log('📍 Port: ' + PORT);
    console.log('🗄️  Database: PostgreSQL');
    console.log('🌐 Environment: ' + (process.env.NODE_ENV || 'development'));
    console.log('✅ Health: http://localhost:' + PORT + '/api/health');
    console.log('🔑 Demo: demo@demo.com / demo123');
    console.log('=================================');
});

// Graceful shutdown
process.on('SIGTERM', async () => {
    console.log('SIGTERM received, shutting down gracefully');
    process.exit(0);
});
