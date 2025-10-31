const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

// Health check koji radi ODMAH - ovo spašava Railway health check!
app.get('/api/health', (req, res) => {
    const dbStatus = process.env.DATABASE_URL ? 'Database: Connecting...' : 'Database: Not connected';
    res.json({ 
        status: 'OK', 
        message: 'CRM Backend is running',
        database: dbStatus,
        timestamp: new Date().toISOString()
    });
});

// Simple in-memory demo
let demoClients = [
    { id: 1, name: 'Demo Client 1', email: 'demo1@test.com', company: 'Test Co' },
    { id: 2, name: 'Demo Client 2', email: 'demo2@test.com', company: 'Test Corp' }
];

app.get('/api/clients', (req, res) => {
    res.json({ 
        success: true, 
        clients: demoClients,
        note: process.env.DATABASE_URL ? 'Database setup in progress' : 'Using demo data'
    });
});

app.post('/api/auth/login', (req, res) => {
    const { email, password } = req.body;
    
    if (email === 'demo@demo.com' && password === 'demo123') {
        res.json({ 
            success: true, 
            user: { id: 1, email: 'demo@demo.com', name: 'Demo User' },
            token: 'demo-token-123'
        });
    } else {
        res.status(401).json({ 
            success: false, 
            message: 'Invalid credentials - try demo@demo.com / demo123'
        });
    }
});

app.get('/', (req, res) => {
    res.json({ 
        message: 'CRM Backend API',
        version: '1.0.0',
        status: 'Running',
        database: process.env.DATABASE_URL ? 'PostgreSQL: Setting up' : 'PostgreSQL: Add service in Railway',
        demo: {
            login: 'demo@demo.com / demo123',
            health_check: '/api/health'
        }
    });
});

// POKRENI SERVER ODMAH - ovo je KLJUČNO za Railway!
const server = app.listen(PORT, '0.0.0.0', () => {
    console.log('🚀 Server started on port', PORT);
    console.log('✅ Health check available at: http://localhost:' + PORT + '/api/health');
    console.log('🔧 Database status:', process.env.DATABASE_URL ? 'CONNECTED' : 'NOT CONNECTED');
    
    // Sada pokušaj setup baze u pozadini
    if (process.env.DATABASE_URL) {
        console.log('🗄️  Starting database setup in background...');
        setupDatabaseInBackground();
    }
});

// Funkcija za setup baze u pozadini
async function setupDatabaseInBackground() {
    try {
        console.log('🔧 Starting background database setup...');
        const { setupDatabase } = require('./database/setup.js');
        await setupDatabase();
        console.log('🎉 Background database setup completed!');
    } catch (error) {
        console.log('⚠️  Background database setup failed:', error.message);
        console.log('ℹ️  App continues running with demo data');
    }
}

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    server.close(() => {
        console.log('Server closed');
        process.exit(0);
    });
});
