const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

// Basic health check - radi čak i bez baze
app.get('/api/health', (req, res) => {
    const dbStatus = process.env.DATABASE_URL ? 'Database: Setting up' : 'Database: Not connected';
    res.json({ 
        status: 'OK', 
        message: 'CRM Backend is running',
        database: dbStatus,
        timestamp: new Date().toISOString()
    });
});

// Simple in-memory demo kada baza nije spremna
let demoClients = [
    { id: 1, name: 'Demo Client 1', email: 'demo1@test.com', company: 'Test Co' },
    { id: 2, name: 'Demo Client 2', email: 'demo2@test.com', company: 'Test Corp' }
];

app.get('/api/clients', (req, res) => {
    res.json({ 
        success: true, 
        clients: demoClients,
        note: 'Using in-memory data until database is ready'
    });
});

app.post('/api/auth/login', (req, res) => {
    const { email, password } = req.body;
    
    // Hardcoded demo login
    if (email === 'demo@demo.com' && password === 'demo123') {
        res.json({ 
            success: true, 
            user: { id: 1, email: 'demo@demo.com', name: 'Demo User' },
            token: 'demo-token-123',
            note: 'Using demo authentication until database is ready'
        });
    } else {
        res.status(401).json({ 
            success: false, 
            message: 'Invalid credentials - try demo@demo.com / demo123'
        });
    }
});

app.get('/', (req, res) => {
    const dbInfo = process.env.DATABASE_URL ? 
        'Database: Connecting...' : 
        'Database: Please add PostgreSQL service in Railway';
    
    res.json({ 
        message: 'CRM Backend API',
        version: '1.0.0',
        status: dbInfo,
        demo: {
            login: 'demo@demo.com / demo123',
            note: 'App works in demo mode until database is ready'
        }
    });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log('🚀 Server started on port', PORT);
    console.log('🔧 Database status:', process.env.DATABASE_URL ? 'CONNECTED' : 'NOT CONNECTED');
    if (!process.env.DATABASE_URL) {
        console.log('💡 Please add PostgreSQL service in Railway dashboard');
    }
});
