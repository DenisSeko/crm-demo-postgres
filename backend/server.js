import express from 'express';
import cors from 'cors';

const app = express();
const PORT = process.env.PORT || 8888;

app.use(cors());
app.use(express.json());

// Osnovni endpoint - bez baze prvo
app.get('/', (req, res) => {
  res.json({ 
    message: '✅ CRM Backend is working!',
    environment: process.env.NODE_ENV || 'development',
    port: PORT,
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK',
    environment: process.env.NODE_ENV || 'development'
  });
});

app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'OK',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString()
  });
});

console.log('🚀 Starting CRM backend server...');
app.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ Server running on port ${PORT}`);
  console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log('✅ Backend is ready!');
});