const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

app.get('/api/health', (req, res) => {
    res.json({ 
        status: 'OK', 
        message: 'Server is running',
        database: 'Check setup logs',
        timestamp: new Date().toISOString()
    });
});

app.get('/', (req, res) => {
    res.json({ 
        message: 'CRM Backend API',
        version: '1.0.0',
        status: 'Database setup may be in progress',
        check: 'View Railway logs for setup status'
    });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log('🚀 Server started on port', PORT);
});
