const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

// In-memory storage
let clients = [
  { id: 1, name: 'Test Client 1', email: 'client1@test.com', company: 'Company A' },
  { id: 2, name: 'Test Client 2', email: 'client2@test.com', company: 'Company B' }
];

// Health check with branch info
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'CRM Backend is running',
    branch: 'development',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString()
  });
});

// Login
app.post('/api/auth/login', (req, res) => {
  const { email, password } = req.body;
  console.log('Login attempt on development:', email);
  
  if (email === 'demo@demo.com' && password === 'demo123') {
    return res.json({ 
      success: true, 
      user: { 
        id: 1, 
        email: 'demo@demo.com', 
        name: 'Demo User (development)'
      },
      token: 'demo-token-development-123'
    });
  }
  
  res.status(401).json({ success: false, message: 'Pogrešni podaci' });
});

// Clients API
app.get('/api/clients', (req, res) => {
  res.json({
    success: true,
    branch: 'development',
    clients: clients
  });
});

app.post('/api/clients', (req, res) => {
  const { name, email, company } = req.body;
  const newClient = {
    id: clients.length + 1,
    name,
    email,
    company,
    branch: 'development',
    created_at: new Date().toISOString()
  };
  clients.push(newClient);
  
  res.json({
    success: true,
    client: newClient
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log('🚀 CRM Backend started successfully!');
  console.log('📍 Port: ' + PORT);
  console.log('🌿 Branch: development');
  console.log('🌐 Environment: ' + (process.env.NODE_ENV || 'development'));
  console.log('✅ Health: http://localhost:' + PORT + '/api/health');
});
