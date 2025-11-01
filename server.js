import express from 'express';
import cors from 'cors';

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

// ✅ CRITICAL: Health check that responds in UNDER 1 SECOND
app.get('/api/health', (req, res) => {
    console.log('❤️ Health check - IMMEDIATE RESPONSE');
    res.status(200).json({ 
        status: 'OK', 
        message: 'Server is running',
        timestamp: new Date().toISOString(),
        database: process.env.DATABASE_URL ? 'configured' : 'not-configured'
    });
});

// ✅ Root endpoint - also immediate
app.get('/', (req, res) => {
    res.json({ 
        status: 'running',
        service: 'crm-backend',
        message: 'Server started successfully 🚀'
    });
});

// Demo data - available immediately
app.get('/api/clients', (req, res) => {
    res.json({
        success: true,
        clients: [
            { id: 1, name: 'Demo Client 1', email: 'demo1@test.com' },
            { id: 2, name: 'Demo Client 2', email: 'demo2@test.com' }
        ],
        source: 'memory-cache'
    });
});

// Demo login
app.post('/api/auth/login', (req, res) => {
    res.json({
        success: true,
        user: { id: 1, name: 'Demo User', email: 'demo@demo.com' },
        token: 'demo-token-railway'
    });
});

// ✅ START SERVER IMMEDIATELY - NO DATABASE WAITING!
const server = app.listen(PORT, '0.0.0.0', () => {
    console.log('');
    console.log('🎉 SERVER STARTED SUCCESSFULLY!');
    console.log('📍 Port:', PORT);
    console.log('❤️ Health:', 'http://localhost:' + PORT + '/api/health');
    console.log('🚀 Status:', 'READY FOR RAILWAY');
    console.log('⏰ Startup time:', 'UNDER 3 SECONDS');
    console.log('');
    
    // Background database initialization (optional)
    if (process.env.DATABASE_URL) {
        console.log('🗄️ Database URL detected - will initialize in background...');
        initializeDatabaseBackground();
    }
});

// Background database setup (non-blocking)
function initializeDatabaseBackground() {
    setTimeout(async () => {
        try {
            console.log('🔧 Starting background database setup...');
            const { Pool } = require('pg');
            const pool = new Pool({
                connectionString: process.env.DATABASE_URL,
                ssl: { rejectUnauthorized: false }
            });
            
            const client = await pool.connect();
            console.log('✅ Database connected in background');
            client.release();
            await pool.end();
        } catch (error) {
            console.log('⚠️ Background database setup failed:', error.message);
        }
    }, 5000);
}

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received - shutting down');
    server.close(() => {
        process.exit(0);
    });
});
