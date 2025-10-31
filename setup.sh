#!/bin/bash
set -e

echo "🚀 CRM DEMO - PostgreSQL Version - Kompletna instalacija i pokretanje"
echo "=================================================="

# Provjera Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js nije instaliran. Instaliraj Node.js prvo."
    echo "📥 Preuzmi s: https://nodejs.org/"
    exit 1
fi

# Provjera Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker nije instaliran. Instaliraj Docker prvo."
    echo "📥 Preuzmi s: https://docker.com/"
    exit 1
fi

echo "✅ Node.js: $(node --version)"
echo "✅ npm: $(npm --version)"
echo "✅ Docker: $(docker --version)"

# Kreiranje direktorija
PROJECT_DIR="crm-demo-postgres"
echo " "
echo "📁 Kreiranje projekta u: $PROJECT_DIR"

rm -rf $PROJECT_DIR
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

echo "✅ Direktorij kreiran"

# Kreiraj kompletnu strukturu direktorija
mkdir -p backend frontend/src/components backend/database/init-scripts database/backup

# 1. Backend package.json
cat > backend/package.json << 'BACKEND_EOF'
{
  "name": "crm-backend",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "node server.js",
    "start": "node server.js",
    "db:init": "node database/init.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "pg": "^8.11.3"
  }
}
BACKEND_EOF

# 2. Database konfiguracija - PORT 5433
cat > backend/database/config.js << 'CONFIG_EOF'
import pkg from 'pg';
const { Pool } = pkg;

export const pool = new Pool({
  user: 'crm_user',
  host: 'localhost',
  database: 'crm_demo',
  password: 'crm_password',
  port: 5433,
});

// Graceful shutdown
process.on('SIGINT', async () => {
  await pool.end();
  process.exit(0);
});
CONFIG_EOF

# 3. Database inicijalizacija
cat > backend/database/init.js << 'INIT_EOF'
import { pool } from './config.js';

async function initDatabase() {
  try {
    console.log('🔄 Inicijalizacija baze podataka...');

    // Kreiraj tabele
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        email VARCHAR(255) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL,
        name VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS clients (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) NOT NULL,
        company VARCHAR(255),
        owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS notes (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        content TEXT NOT NULL,
        client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    console.log('✅ Tabele kreirane uspješno');

    // Seed podaci
    const demoPassword = 'demo123';
    
    // Ubaci demo korisnika
    const userResult = await pool.query(
      `INSERT INTO users (email, password, name) 
       VALUES ($1, $2, $3) 
       ON CONFLICT (email) DO NOTHING
       RETURNING id`,
      ['demo@demo.com', demoPassword, 'Demo User']
    );

    if (userResult.rows.length > 0) {
      const userId = userResult.rows[0].id;
      
      // Ubaci demo klijente
      await pool.query(`
        INSERT INTO clients (name, email, company, owner_id) 
        VALUES 
          ('Alpha Corp', 'contact@alpha.com', 'Alpha Corp', $1),
          ('Beta LLC', 'info@beta.com', 'Beta LLC', $1),
          ('Gamma Inc', 'hello@gamma.com', 'Gamma Inc', $1)
        ON CONFLICT DO NOTHING
      `, [userId]);

      // Ubaci demo bilješke
      const clientResult = await pool.query('SELECT id FROM clients LIMIT 1');
      const clientId = clientResult.rows[0]?.id;
      
      if (clientId) {
        await pool.query(`
          INSERT INTO notes (content, client_id) 
          VALUES 
            ('Prvi kontakt - zainteresirani za naš proizvod', $1),
            ('Slanje ponude - čekamo odgovor', $1)
          ON CONFLICT DO NOTHING
        `, [clientId]);
      }

      console.log('✅ Seed podaci dodani uspješno');
    } else {
      console.log('ℹ️  Demo user već postoji');
    }

    console.log('🎉 Baza podataka je spremna!');
    
  } catch (error) {
    console.error('❌ Greška pri inicijalizaciji baze:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

initDatabase();
INIT_EOF

# 4. Backend server.js
cat > backend/server.js << 'SERVER_EOF'
import express from 'express';
import cors from 'cors';
import { pool } from './database/config.js';

const app = express();
const PORT = 3001;

app.use(cors({
  origin: 'http://localhost:5173',
  credentials: true
}));
app.use(express.json());

// Test konekcije na bazu pri pokretanju
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

// Osnovni endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: 'CRM Backend API is running!',
    timestamp: new Date().toISOString()
  });
});

// Health check
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ 
      status: 'OK', 
      database: 'connected',
      timestamp: new Date().toISOString()
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
    const tableData = {};
    
    for (let table of tablesResult.rows) {
      const tableName = table.table_name;
      
      // Broj redova
      const countResult = await client.query(`SELECT COUNT(*) as count FROM ${tableName}`);
      tableCounts[tableName] = parseInt(countResult.rows[0].count);
      
      // Prvih 5 redova (ako postoje)
      if (tableCounts[tableName] > 0) {
        const dataResult = await client.query(`SELECT * FROM ${tableName} LIMIT 3`);
        tableData[tableName] = dataResult.rows;
      } else {
        tableData[tableName] = [];
      }
    }

    client.release();

    const debugInfo = {
      tables: tablesResult.rows.map(row => row.table_name),
      counts: tableCounts,
      sampleData: tableData,
      connection: 'successful',
      timestamp: new Date().toISOString()
    };

    console.log('📊 Debug info:', debugInfo);
    res.json(debugInfo);

  } catch (error) {
    console.error('❌ Debug database error:', error);
    res.status(500).json({
      error: error.message,
      connection: 'failed',
      timestamp: new Date().toISOString()
    });
  }
});

// Stats endpoint - AŽURIRANA VERZIJA
app.get('/api/clients/stats', async (req, res) => {
  try {
    console.log('📊 Getting stats...');
    
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

    console.log('📈 Stats calculated:', stats);
    res.json(stats);
  } catch (error) {
    console.error('❌ Get stats error:', error);
    res.status(500).json({ 
      error: 'Database error',
      details: error.message 
    });
  }
});

// Login endpoint
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

// Clients endpoints s boljim error handlingom
app.get('/api/clients', async (req, res) => {
  try {
    console.log('📋 Getting clients list...');
    
    const result = await pool.query('SELECT * FROM clients ORDER BY created_at DESC');
    
    console.log(`✅ Found ${result.rows.length} clients`);
    res.json(result.rows);
    
  } catch (error) {
    console.error('❌ Get clients error:', error.message);
    
    res.status(500).json({ 
      error: 'Database error',
      message: error.message,
      details: 'Check if database is running and tables exist'
    });
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
    res.json({ message: 'Client deleted', client: result.rows[0] });
  } catch (error) {
    console.error('Delete client error:', error);
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
    // Provjeri da klijent postoji
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
    
    console.log('✅ Note added successfully');
    res.json(result.rows[0]);
  } catch (error) {
    console.error('💥 Add note error:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

// DELETE endpoint za brisanje bilješki
app.delete('/api/notes/:id', async (req, res) => {
  const { id } = req.params;

  console.log('🗑️ Deleting note:', id);

  try {
    const result = await pool.query(
      'DELETE FROM notes WHERE id = $1 RETURNING *',
      [id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Bilješka nije pronađena' });
    }
    
    console.log('✅ Note deleted:', result.rows[0].id);
    res.json({ 
      message: 'Bilješka uspješno obrisana', 
      note: result.rows[0] 
    });
  } catch (error) {
    console.error('Delete note error:', error);
    res.status(500).json({ error: 'Greška pri brisanju bilješke' });
  }
});

// Novi endpoint za dobivanje broja bilješki po klijentu
app.get('/api/clients/notes-count', async (req, res) => {
  try {
    console.log('📊 Getting notes count per client...');
    
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

    console.log('✅ Notes count per client:', notesCount);
    res.json(notesCount);
  } catch (error) {
    console.error('❌ Get notes count error:', error);
    res.status(500).json({ 
      error: 'Database error',
      details: error.message 
    });
  }
});

// Start server
app.listen(PORT, async () => {
  console.log(`🚀 Backend server running on http://localhost:${PORT}`);
  console.log(`📊 PostgreSQL database: crm_demo`);
  console.log(`🔐 Demo login: demo@demo.com / demo123`);
  console.log(`🐛 Debug endpoint: http://localhost:${PORT}/api/debug/database`);
  
  // Testiraj konekciju pri pokretanju
  const dbConnected = await testDatabaseConnection();
  if (!dbConnected) {
    console.log('❌ WARNING: Cannot connect to database!');
    console.log('💡 Check if PostgreSQL container is running: docker-compose ps');
    console.log('💡 Check database port and credentials');
  }
});
SERVER_EOF

echo "✅ Backend server s PostgreSQL kreiran"

# 5. Frontend package.json
cat > frontend/package.json << 'FRONTEND_EOF'
{
  "name": "crm-frontend",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "vue": "^3.3.4",
    "vue-router": "^4.2.4",
    "pinia": "^2.1.6",
    "axios": "^1.5.0"
  },
  "devDependencies": {
    "vite": "^4.4.5",
    "@vitejs/plugin-vue": "^4.3.4"
  }
}
FRONTEND_EOF

# 6. Frontend vite.config.js
cat > frontend/vite.config.js << 'VITE_EOF'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:3001',
        changeOrigin: true,
        secure: false
      }
    }
  }
})
VITE_EOF

# 7. Frontend index.html
cat > frontend/index.html << 'HTML_EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>CRM Demo - PostgreSQL</title>
    <script src="https://cdn.tailwindcss.com"></script>
  </head>
  <body class="bg-gray-50 min-h-screen">
    <div id="app"></div>
    <script type="module" src="/src/main.js"></script>
  </body>
</html>
HTML_EOF

# 8. Frontend main.js - ISPRAVLJENA VUE ROUTER KONFIGURACIJA
cat > frontend/src/main.js << 'MAIN_EOF'
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import { createRouter, createWebHistory } from 'vue-router'
import App from './App.vue'

// Kreiraj router
const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/',
      name: 'Home',
      component: App
    }
  ]
})

const app = createApp(App)
app.use(createPinia())
app.use(router)
app.mount('#app')
MAIN_EOF

# 9. Frontend App.vue - ISPRAVLJENA VUE ROUTER LOGIKA
cat > frontend/src/App.vue << 'APP_EOF'
<template>
  <div class="min-h-screen bg-gray-50">
    <!-- Loader -->
    <Loader v-if="showLoader" />
    
    <!-- Header -->
    <AppHeader 
      :user="user" 
      @go-home="goToHome" 
      @logout="logout" 
    />

    <!-- Main Content -->
    <transition name="fade">
      <div v-if="!user && !showLoader">
        <HomePage 
          v-if="showHomepage" 
          @go-to-login="goToLogin" 
        />
        <LoginForm 
          v-else 
          :is-logging-in="isLoggingIn" 
          @login="login" 
          @go-home="goToHome" 
        />
      </div>
    </transition>

    <!-- Dashboard -->
    <transition name="fade">
      <Dashboard v-if="user && !showLoader" />
    </transition>
  </div>
</template>

<script setup>
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'

// Components
import AppHeader from './components/AppHeader.vue'
import HomePage from './components/HomePage.vue'
import LoginForm from './components/LoginForm.vue'
import Loader from './components/Loader.vue'
import Dashboard from './components/Dashboard.vue'

const router = useRouter()

// State
const user = ref(null)
const showHomepage = ref(true)
const showLoader = ref(false)
const isLoggingIn = ref(false)

// Methods
const goToLogin = () => {
  showHomepage.value = false
  router.push('/?login=true')
}

const goToHome = () => {
  showHomepage.value = true
  router.push('/')
}

const login = async (loginData) => {
  isLoggingIn.value = true
  
  try {
    // Button spinner delay
    await new Promise(resolve => setTimeout(resolve, 500))
    
    const response = await axios.post('/api/login', loginData)
    const { token, user: userData } = response.data
    
    // Show main loader
    showLoader.value = true
    
    // Simulate data loading
    await new Promise(resolve => setTimeout(resolve, 1500))
    
    localStorage.setItem('token', token)
    localStorage.setItem('user', JSON.stringify(userData))
    user.value = userData
    axios.defaults.headers.common['Authorization'] = `Bearer ${token}`
    
    goToHome()
    
  } catch (error) {
    console.error('Login failed:', error.response?.data || error.message)
    alert('Pogrešni podaci za prijavu')
  } finally {
    isLoggingIn.value = false
    showLoader.value = false
  }
}

const logout = () => {
  localStorage.removeItem('token')
  localStorage.removeItem('user')
  user.value = null
  delete axios.defaults.headers.common['Authorization']
  goToHome()
}

// Watchers & Lifecycle
watch(() => router.currentRoute.value.query, (newQuery) => {
  showHomepage.value = newQuery.login !== 'true'
}, { immediate: true })

onMounted(() => {
  // Check for saved user session
  const savedUser = localStorage.getItem('user')
  const savedToken = localStorage.getItem('token')
  
  if (savedUser && savedToken) {
    user.value = JSON.parse(savedUser)
    axios.defaults.headers.common['Authorization'] = `Bearer ${savedToken}`
  }
})
</script>

<style>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.5s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
APP_EOF

# 10. Frontend komponente

# 10.1 AppHeader.vue
cat > frontend/src/components/AppHeader.vue << 'APPHEADER_EOF'
<template>
  <nav class="bg-white shadow-sm border-b">
    <div class="max-w-6xl mx-auto px-4 py-3">
      <h1 class="text-xl font-semibold">
        <a href="#" @click.prevent="$emit('go-home')" class="text-blue-600 hover:text-blue-800">
          CRM Demo - PostgreSQL (Port 5433)
        </a>
      </h1>
      <div class="flex justify-between items-center">
        <div v-if="user" class="text-sm text-gray-600">
          Prijavljeni ste kao: {{ user.name }}
          <button @click="$emit('logout')" class="ml-4 text-red-600 hover:text-red-800">
            Odjava
          </button>
        </div>
        <div class="text-xs text-green-600 font-semibold">
          🗄️ PostgreSQL (5433)
        </div>
      </div>
    </div>
  </nav>
</template>

<script setup>
defineProps({
  user: {
    type: Object,
    default: null
  }
})

defineEmits(['go-home', 'logout'])
</script>
APPHEADER_EOF

# 10.2 HomePage.vue
cat > frontend/src/components/HomePage.vue << 'HOMEPAGE_EOF'
<template>
  <div class="max-w-3xl mx-auto mt-20 p-6 bg-white rounded-lg shadow-md text-center">
    <h2 class="text-3xl font-bold mb-6">Dobrodošli u CRM Demo!</h2>
    <p class="text-gray-700 mb-8">
      Ovaj demo prikazuje osnovne funkcionalnosti CRM sustava s Vue 3, Node.js i PostgreSQL (port 5433).
    </p>
    <button @click="$emit('go-to-login')"
      class="bg-blue-600 text-white py-3 px-6 rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500">
      Idi na prijavu
    </button>
    
    <div class="mt-8 grid grid-cols-1 md:grid-cols-3 gap-4 text-left">
      <div class="p-4 bg-blue-50 rounded-lg">
        <h3 class="font-semibold text-blue-800">📊 Dashboard</h3>
        <p class="text-sm text-blue-600 mt-2">Pregled klijenata i statistika</p>
      </div>
      <div class="p-4 bg-green-50 rounded-lg">
        <h3 class="font-semibold text-green-800">👥 Klijenti</h3>
        <p class="text-sm text-green-600 mt-2">Upravljanje klijentima i bilješkama</p>
      </div>
      <div class="p-4 bg-purple-50 rounded-lg">
        <h3 class="font-semibold text-purple-800">🗄️ Baza</h3>
        <p class="text-sm text-purple-600 mt-2">PostgreSQL na portu 5433</p>
      </div>
    </div>
  </div>
</template>

<script setup>
defineEmits(['go-to-login'])
</script>
HOMEPAGE_EOF

# 10.3 LoginForm.vue
cat > frontend/src/components/LoginForm.vue << 'LOGINFORM_EOF'
<template>
  <div class="max-w-md mx-auto mt-20 p-6 bg-white rounded-lg shadow-md">
    <h2 class="text-2xl font-bold mb-6 text-center">Prijava</h2>
    <form @submit.prevent="$emit('login', loginData)" class="space-y-4">
      <div>
        <label class="block text-sm font-medium text-gray-700">Email</label>
        <input v-model="loginData.email" type="email"
          class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          required>
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700">Lozinka</label>
        <input v-model="loginData.password" type="password"
          class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          required>
      </div>
      <button type="submit"
        class="w-full bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 flex items-center justify-center"
        :disabled="isLoggingIn">
        <span v-if="isLoggingIn" class="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></span>
        {{ isLoggingIn ? 'Prijavljujem...' : 'Prijavi se' }}
      </button>
    </form>
    
    <div class="mt-4 p-3 bg-yellow-50 rounded-md text-sm">
      <strong>Demo pristup:</strong><br>
      Email: demo@demo.com<br>
      Lozinka: demo123
    </div>

    <div class="mt-4 text-center">
      <a href="#" @click.prevent="$emit('go-home')" class="text-blue-600 hover:text-blue-800 text-sm">
        ← Povratak na početnu
      </a>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive } from 'vue'

defineProps({
  isLoggingIn: {
    type: Boolean,
    default: false
  }
})

defineEmits(['login', 'go-home'])

const loginData = reactive({
  email: 'demo@demo.com',
  password: 'demo123'
})
</script>
LOGINFORM_EOF

# 10.4 Loader.vue
cat > frontend/src/components/Loader.vue << 'LOADER_EOF'
<template>
  <div class="fixed inset-0 bg-white z-50 flex items-center justify-center">
    <div class="text-center">
      <div class="animate-spin rounded-full h-16 w-16 border-b-2 border-blue-600 mx-auto mb-4"></div>
      <p class="text-gray-600 text-lg">{{ message }}</p>
      <p class="text-gray-400 text-sm">{{ subMessage }}</p>
    </div>
  </div>
</template>

<script setup>
defineProps({
  message: {
    type: String,
    default: 'Učitavanje...'
  },
  subMessage: {
    type: String,
    default: 'Prijavljujemo vas u sustav'
  }
})
</script>
LOADER_EOF

# 10.5 Dashboard.vue
cat > frontend/src/components/Dashboard.vue << 'DASHBOARD_EOF'
<template>
  <div class="max-w-6xl mx-auto p-6">
    <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
      <div class="bg-white p-6 rounded-lg shadow-sm border">
        <h3 class="text-lg font-semibold text-gray-700">Ukupno klijenata</h3>
        <p class="text-3xl font-bold text-blue-600">{{ stats.clients }}</p>
      </div>
      <div class="bg-white p-6 rounded-lg shadow-sm border">
        <h3 class="text-lg font-semibold text-gray-700">Ukupno bilješki</h3>
        <p class="text-3xl font-bold text-green-600">{{ stats.totalNotes || 0 }}</p>
      </div>
      <div class="bg-white p-6 rounded-lg shadow-sm border">
        <h3 class="text-lg font-semibold text-gray-700">Zadnja bilješka</h3>
        <p class="text-sm text-gray-600 mt-1 truncate">{{ stats.lastNote || 'Nema bilježki' }}</p>
      </div>
      <div class="bg-white p-6 rounded-lg shadow-sm border">
        <h3 class="text-lg font-semibold text-gray-700">Akcije</h3>
        <button @click="showNewClient = true"
          class="mt-2 bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 w-full">
          + Novi klijent
        </button>
      </div>
    </div>

    <div v-if="showNewClient" class="bg-white p-6 rounded-lg shadow-sm border mb-6">
      <h3 class="text-lg font-semibold mb-4">Novi klijent</h3>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Ime klijenta *</label>
          <input v-model="newClient.name" placeholder="Unesite ime klijenta"
            class="border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 w-full" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Email *</label>
          <input v-model="newClient.email" placeholder="email@primjer.com"
            class="border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 w-full" />
        </div>
        <div class="md:col-span-2">
          <label class="block text-sm font-medium text-gray-700 mb-1">Tvrtka</label>
          <input v-model="newClient.company" placeholder="Naziv tvrtke (opcionalno)"
            class="border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 w-full" />
        </div>
      </div>
      <div class="flex gap-2 mt-4">
        <button @click="createClient"
          class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 flex items-center gap-2"
          :disabled="!newClient.name || !newClient.email || creatingClient">
          <span v-if="creatingClient" class="animate-spin">⏳</span>
          <span v-else>💾</span>
          {{ creatingClient ? 'Spremanje...' : 'Spremi' }}
        </button>
        <button @click="cancelNewClient"
          class="bg-gray-500 text-white px-4 py-2 rounded-md hover:bg-gray-600 flex items-center gap-2">
          <span>❌</span>
          Otkaži
        </button>
      </div>
    </div>

    <div class="bg-white rounded-lg shadow-sm border">
      <div class="p-6 border-b">
        <div class="flex justify-between items-center">
          <h3 class="text-lg font-semibold">Klijenti</h3>
          <div class="text-sm text-gray-600">
            Ukupno bilješki u sustavu: <span class="font-bold text-green-600">{{ stats.totalNotes }}</span>
          </div>
        </div>
      </div>

      <div v-if="loading" class="p-6 text-center text-gray-500">
        <div class="flex justify-center items-center gap-2">
          <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600"></div>
          Učitavanje klijenata...
        </div>
      </div>

      <div v-else-if="clients.length === 0" class="p-6 text-center text-gray-500">
        <div class="max-w-md mx-auto">
          <div class="text-4xl mb-4">📊</div>
          <h3 class="text-lg font-semibold mb-2">Nema klijenata</h3>
          <p class="text-sm mb-4">Dodajte prvog klijenta kako biste počeli koristiti CRM sustav.</p>
          <button @click="showNewClient = true" class="bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700">
            + Dodaj prvog klijenta
          </button>
        </div>
      </div>

      <ul v-else class="divide-y">
        <li v-for="client in clients" :key="client.id" class="p-6 hover:bg-gray-50 transition-colors duration-200">
          <div class="flex justify-between items-start">
            <div class="flex-1">
              <div class="flex items-center gap-3 mb-2">
                <h4 class="font-semibold text-lg text-gray-800">{{ client.name }}</h4>
                
                <!-- Normalan prikaz broja bilješki -->
                <span class="bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded-full">
                  {{ getNoteCountDisplay(client.id) }}
                </span>
              </div>
              <p class="text-gray-600 flex items-center gap-2">
                <span>📧</span>
                {{ client.email }}
              </p>
              <p class="text-sm text-gray-500 flex items-center gap-2 mt-1">
                <span>🏢</span>
                {{ client.company || 'Nema podataka o tvrtki' }}
              </p>
              <p class="text-xs text-gray-400 mt-2">
                Kreiran: {{ new Date(client.created_at).toLocaleDateString('hr-HR') }}
              </p>
            </div>
            <div class="flex gap-2">
              <button @click="initLoaderAndToggleNotes(client.id)"
                class="text-blue-600 hover:text-blue-800 px-3 py-2 rounded border border-blue-200 hover:bg-blue-50 transition-colors duration-200 flex items-center gap-2"
                :title="notesOpen[client.id] ? 'Sakrij bilješke' : 'Prikaži bilješke'"
                :disabled="loadingNotes[client.id]">
                <span>{{ notesOpen[client.id] ? '📕' : '📘' }}</span>
                
                <!-- Loader na buttonu -->
                <template v-if="loadingNotes[client.id]">
                  <div class="flex items-center gap-1">
                    <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-500"></div>
                    Učitavanje...
                  </div>
                </template>
                <template v-else>
                  {{ notesOpen[client.id] ? 'Sakrij' : 'Bilješke' }} ({{ getNoteCountDisplay(client.id) }})
                </template>
              </button>
              <button @click="deleteClient(client.id)"
                class="text-red-600 hover:text-red-800 px-3 py-2 rounded border border-red-200 hover:bg-red-50 transition-colors duration-200 flex items-center gap-2"
                title="Obriši klijenta"
                :disabled="deletingClientId === client.id">
                <span v-if="deletingClientId === client.id" class="animate-spin">⏳</span>
                <span v-else>🗑️</span>
                {{ deletingClientId === client.id ? 'Briše se...' : 'Obriši' }}
              </button>
            </div>
          </div>

          <div v-if="notesOpen[client.id]" class="mt-4 ml-4 p-4 bg-gray-50 rounded-lg border">
            <h5 class="font-semibold mb-3 flex items-center gap-2 text-gray-700">
              <span>📝</span>
              Bilješke za {{ client.name }}
              <span class="bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded-full">
                {{ getNoteCountDisplay(client.id) }}
              </span>
            </h5>

            <!-- Loader za bilješke -->
            <div v-if="loadingNotes[client.id]" class="text-center py-4">
              <div class="flex justify-center items-center gap-2 text-gray-500">
                <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
                <div>Učitavanje bilješki...</div>
              </div>
            </div>

            <div v-else-if="clientNotes[client.id]?.length === 0"
              class="text-gray-500 text-sm mb-3 p-4 bg-white rounded border text-center">
              <div class="text-2xl mb-2">📄</div>
              <p>Nema bilježki za ovog klijenta.</p>
              <p class="text-xs mt-1">Dodajte prvu bilješku ispod.</p>
            </div>

            <ul v-else class="space-y-3 mb-4">
              <li v-for="note in clientNotes[client.id]" :key="note.id"
                class="bg-white p-4 rounded border hover:shadow-sm transition-shadow duration-200">
                <div class="flex justify-between items-start gap-3">
                  <div class="flex-1">
                    <p class="text-gray-800">{{ note.content }}</p>
                    <span class="text-xs text-gray-400 block mt-2">
                      📅 {{ new Date(note.created_at).toLocaleString('hr-HR') }}
                    </span>
                  </div>
                  <button @click="deleteNote(note.id, client.id)"
                    class="text-red-500 hover:text-red-700 transition-colors duration-200 flex-shrink-0 p-1 rounded hover:bg-red-50"
                    title="Obriši bilješku" :disabled="deletingNoteId === note.id">
                    <span v-if="deletingNoteId === note.id" class="animate-spin">⏳</span>
                    <span v-else>🗑️</span>
                  </button>
                </div>
              </li>
            </ul>

            <div v-if="!loadingNotes[client.id]" class="flex gap-2">
              <input v-model="newNote[client.id]" @keyup.enter="addNote(client.id)"
                placeholder="Unesite novu bilješku..."
                class="flex-1 border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                :disabled="addingNoteClientId === client.id" />
              <button @click="addNote(client.id)"
                class="bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 text-sm flex items-center gap-2 transition-colors duration-200"
                :disabled="!newNote[client.id] || addingNoteClientId === client.id">
                <span v-if="addingNoteClientId === client.id" class="animate-spin">⏳</span>
                <span v-else>➕</span>
                {{ addingNoteClientId === client.id ? 'Dodaje se...' : 'Dodaj' }}
              </button>
            </div>
          </div>
        </li>
      </ul>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, nextTick } from 'vue'
import axios from 'axios'

const clients = ref([])
const clientNotes = reactive({})
const notesCount = reactive({})
const notesOpen = reactive({})
const loadingNotes = reactive({}) // Loading state za pojedinačne bilješke
const newNote = reactive({})
const showNewClient = ref(false)
const newClient = reactive({
  name: '',
  email: '',
  company: ''
})
const stats = reactive({
  clients: 0,
  totalNotes: 0,
  lastNote: ''
})
const loading = ref(true)
const deletingNoteId = ref(null)
const addingNoteClientId = ref(null)
const creatingClient = ref(false)
const deletingClientId = ref(null)

// Nova funkcija koja inicijalizira loader i onda poziva toggleNotes
const initLoaderAndToggleNotes = async (id) => {
  console.log('🔄 Inicijaliziram loader za klijenta:', id)
  
  // Inicijaliziraj loader na click event
  loadingNotes[id] = true
  
  // Sačekaj da Vue renderira promjenu
  await nextTick()
  
  // Dodaj mali delay da se loader sigurno vidi
  await new Promise(resolve => setTimeout(resolve, 300))
  
  // Pozovi originalnu funkciju
  await toggleNotes(id)
}

const toggleNotes = async (id) => {
  // Ako već postoje podaci, samo toggle-aj bez loadera
  if (clientNotes[id]) {
    notesOpen[id] = !notesOpen[id]
    loadingNotes[id] = false
    return
  }
  
  // Ako nemamo podatke, učitaj ih
  notesOpen[id] = true
  await loadNotes(id)
}

const loadNotes = async (id) => {
  try {
    console.log('📝 Učitavam bilješke za klijenta:', id)
    
    // Dodaj veći delay da se loader jasno vidi
    await new Promise(resolve => setTimeout(resolve, 1000))
    
    const response = await axios.get(`/api/clients/${id}/notes`)
    clientNotes[id] = response.data
    console.log('✅ Bilješke učitane:', clientNotes[id].length)
    
    // Ažuriraj notesCount
    if (notesCount[id]) {
      notesCount[id].count = clientNotes[id].length
    }
  } catch (error) {
    console.error('Greška pri učitavanju bilješki:', error)
    alert('Greška pri učitavanju bilješki: ' + (error.response?.data?.error || error.message))
  } finally {
    // Ugasi loader
    loadingNotes[id] = false
  }
}

// Funkcija za učitavanje broja bilješki po klijentu
const loadNotesCount = async () => {
  try {
    console.log('📊 Učitavam broj bilješki po klijentu...')
    const response = await axios.get('/api/clients/notes-count')
    
    // Očisti prethodne podatke
    Object.keys(notesCount).forEach(key => delete notesCount[key])
    
    // Postavi nove podatke
    Object.assign(notesCount, response.data)
    console.log('✅ Broj bilješki po klijentu učitano:', notesCount)
  } catch (error) {
    console.error('Greška pri učitavanju broja bilješki:', error)
    // Fallback: pokušaj ručno izračunati
    calculateNotesCountFallback()
  }
}

// Fallback funkcija ako endpoint ne radi
const calculateNotesCountFallback = () => {
  console.log('🔄 Koristim fallback za brojanje bilješki...')
  clients.value.forEach(client => {
    if (!notesCount[client.id]) {
      notesCount[client.id] = {
        count: clientNotes[client.id]?.length || 0,
        name: client.name
      }
    }
  })
}

const loadClients = async () => {
  try {
    loading.value = true
    console.log('📋 Učitavam klijente...')
    const response = await axios.get('/api/clients')
    clients.value = response.data
    console.log('✅ Klijenti učitani:', clients.value.length)
    
    // UČITAJ BROJ BILJEŠKI NAKON KLIJENATA
    await loadNotesCount()
    await loadStats()
  } catch (error) {
    console.error('Greška pri učitavanju klijenata:', error)
    alert('Greška pri učitavanju klijenata: ' + (error.response?.data?.error || error.message))
  } finally {
    loading.value = false
  }
}

const createClient = async () => {
  if (!newClient.name || !newClient.email) {
    alert('Ime i email su obavezni')
    return
  }

  try {
    creatingClient.value = true
    console.log('➕ Kreiranje klijenta:', newClient)
    const response = await axios.post('/api/clients', newClient)
    console.log('✅ Klijent kreiran:', response.data)
    
    Object.assign(newClient, { name: '', email: '', company: '' })
    showNewClient.value = false
    await loadClients()
  } catch (error) {
    console.error('Greška pri kreiranju klijenta:', error)
    alert('Greška pri kreiranju klijenta: ' + (error.response?.data?.error || error.message))
  } finally {
    creatingClient.value = false
  }
}

const cancelNewClient = () => {
  showNewClient.value = false
  Object.assign(newClient, { name: '', email: '', company: '' })
}

const deleteClient = async (id) => {
  const client = clients.value.find(c => c.id === id)
  if (!confirm(`Jeste li sigurni da želite obrisati klijenta "${client.name}" i sve njegove bilješke?`)) return

  try {
    deletingClientId.value = id
    console.log('🗑️ Brisanje klijenta:', id)
    await axios.delete(`/api/clients/${id}`)
    console.log('✅ Klijent obrisan')
    
    await loadClients()
    await loadStats()
  } catch (error) {
    console.error('Greška pri brisanju klijenata:', error)
    alert('Greška pri brisanju klijenata: ' + (error.response?.data?.error || error.message))
  } finally {
    deletingClientId.value = null
  }
}

const addNote = async (id) => {
  if (!newNote[id]?.trim()) {
    alert('Unesite tekst bilješke')
    return
  }

  try {
    addingNoteClientId.value = id
    console.log('➕ Dodavanje bilješke za klijenta:', id, 'Sadržaj:', newNote[id])
    await axios.post(`/api/clients/${id}/notes`, { content: newNote[id] })
    newNote[id] = ''
    
    // OSVJEŽI PODATKE
    await loadNotesCount()
    if (notesOpen[id]) {
      await loadNotes(id)
    }
    await loadStats()
    console.log('✅ Bilješka dodana')
  } catch (error) {
    console.error('Greška pri dodavanju bilješke:', error)
    alert('Greška pri dodavanju bilješke: ' + (error.response?.data?.error || error.message))
  } finally {
    addingNoteClientId.value = null
  }
}

const deleteNote = async (noteId, clientId) => {
  if (!confirm('Jeste li sigurni da želite obrisati ovu bilješku?')) return

  try {
    deletingNoteId.value = noteId
    console.log('🗑️ Brisanje bilješke:', noteId)
    
    await axios.delete(`/api/notes/${noteId}`)
    
    // OSVJEŽI PODATKE
    await loadNotesCount()
    await loadNotes(clientId)
    await loadStats()
    console.log('✅ Bilješka obrisana')
  } catch (error) {
    console.error('Greška pri brisanju bilješke:', error)
    
    if (error.response?.status === 404) {
      alert('Bilješka nije pronađena. Možda je već obrisana.')
    } else {
      alert('Greška pri brisanju bilješke: ' + (error.response?.data?.error || error.message))
    }
  } finally {
    deletingNoteId.value = null
  }
}

const loadStats = async () => {
  try {
    const response = await axios.get('/api/clients/stats')
    Object.assign(stats, response.data)
    console.log('📊 Statistika učitana:', stats)
  } catch (error) {
    console.error('Greška pri učitavanju statistike:', error)
  }
}

const getNoteCount = (clientId) => {
  return notesCount[clientId]?.count || clientNotes[clientId]?.length || 0
}

const getNoteCountDisplay = (clientId) => {
  const count = getNoteCount(clientId)
  
  // Pravilno sklanjanje za hrvatski jezik
  if (count === 1) {
    return '1 bilješka'
  } else if (count >= 2 && count <= 4) {
    return `${count} bilješke`
  } else {
    return `${count} bilješki`
  }
}

// Inicijalizacija pri pokretanju
onMounted(() => {
  loadClients()
})
</script>
DASHBOARD_EOF

# 12. Docker Compose - PORT 5433
cat > docker-compose.yml << 'DOCKER_EOF'
version: '3.8'
services:
  postgres:
    image: postgres:15
    container_name: crm_postgres
    environment:
      POSTGRES_DB: crm_demo
      POSTGRES_USER: crm_user
      POSTGRES_PASSWORD: crm_password
    ports:
      - "5433:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backend/database/init-scripts:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U crm_user -d crm_demo"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
DOCKER_EOF

# 13. Start skripta - ažurirana za port 5433
cat > start.sh << 'START_EOF'
#!/bin/bash

echo "🚀 CRM DEMO - PostgreSQL Version (Port 5433)"

# Provjera je li Docker pokrenut
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker nije pokrenut. Pokreni Docker prvo."
    exit 1
fi

# Funkcija za pokretanje PostgreSQL
start_postgres() {
    echo "🗄️  Pokrećem PostgreSQL na portu 5433..."
    
    # Zaustavi postojeći PostgreSQL ako radi
    docker-compose down 2>/dev/null || true
    
    # Pokreni novi
    docker-compose up -d postgres
    
    POSTGRES_READY_TIMEOUT=30
    echo "⏳ Čekam PostgreSQL na portu 5433 (timeout: $((POSTGRES_READY_TIMEOUT*2)) sekundi)..."
    for ((i=1; i<=POSTGRES_READY_TIMEOUT; i++)); do
        if docker-compose exec -T postgres pg_isready -U crm_user -d crm_demo > /dev/null 2>&1; then
            echo "✅ PostgreSQL spreman na portu 5433!"
            return 0
        fi
        echo "⏳ Još čekam PostgreSQL... ($i/$POSTGRES_READY_TIMEOUT)"
        sleep 2
    done
    echo "❌ PostgreSQL nije responsive nakon $((POSTGRES_READY_TIMEOUT*2)) sekundi"
    return 1
}

# Funkcija za inicijalizaciju baze
init_database() {
    echo "🔄 Inicijaliziram bazu..."
    cd backend
    if node database/init.js; then
        echo "✅ Baza inicijalizirana!"
    else
        echo "❌ Greška pri inicijalizaciji baze"
        exit 1
    fi
    cd ..
}

# Funkcija za instalaciju dependencies
install_deps() {
    echo "📦 Instaliram dependencies..."
    
    cd backend
    if [ ! -d "node_modules" ]; then
        echo "Instaliram backend dependencies..."
        npm install
    fi
    cd ..
    
    cd frontend
    if [ ! -d "node_modules" ]; then
        echo "Instaliram frontend dependencies..."
        npm install
    fi
    cd ..
}

# Funkcija za pokretanje servisa
start_services() {
    echo "🔧 Pokrećem servise..."
    
    # Zaustavi postojeće procese
    pkill -f "node.*server.js" 2>/dev/null || true
    pkill -f "vite" 2>/dev/null || true
    
    # Pokreni backend
    cd backend
    npm run dev &
    BACKEND_PID=$!
    echo "✅ Backend pokrenut (PID: $BACKEND_PID)"
    cd ..
    
    # Sačekaj da backend pokrene
    echo "⏳ Čekam backend..."
    sleep 3
    
    # Pokreni frontend
    cd frontend
    npm run dev &
    FRONTEND_PID=$!
    echo "✅ Frontend pokrenut (PID: $FRONTEND_PID)"
    cd ..
}

# Glavni dio
cd "$(dirname "$0")"

echo "=================================================="
echo "🔄 Pokrećem CRM Demo..."
echo "=================================================="

start_postgres
install_deps
init_database
start_services

echo " "
echo "=================================================="
echo "🎉 CRM DEMO S POSTGRESQL JE POKRENUT!"
echo "=================================================="
echo "🌐 Frontend: http://localhost:5173"
echo "🔧 Backend:  http://localhost:3001"
echo "🗄️  PostgreSQL: localhost:5433"
echo " "
echo "🔐 Demo login: demo@demo.com / demo123"
echo " "
echo "📝 Funkcionalnosti:"
echo "   ✅ Moderni Vue 3 frontend"
echo "   ✅ Node.js backend API"
echo "   ✅ PostgreSQL baza podataka (port 5433)"
echo "   ✅ Upravljanje klijentima (CRUD)"
echo "   ✅ Bilješke za klijente"
echo "   ✅ Statistika"
echo "   ✅ Loader između stranica"
echo " "
echo "🛑 Zaustavi sa: Ctrl+C"
echo "=================================================="

# Cleanup funkcija
cleanup() {
    echo " "
    echo "🛑 Zaustavljam servise..."
    kill $BACKEND_PID $FRONTEND_PID 2>/dev/null || true
    docker-compose down
    echo "✅ Zaustavljeno!"
    exit 0
}

trap cleanup INT

# Beskonačna petlja
while true; do
    sleep 60
done
START_EOF

chmod +x start.sh

# 14. Stop skripta
cat > stop.sh << 'STOP_EOF'
#!/bin/bash
echo "🛑 Zaustavljam CRM Demo..."
docker-compose down 2>/dev/null
pkill -f "node.*server.js" 2>/dev/null
pkill -f "vite" 2>/dev/null
echo "✅ Sve zaustavljeno!"
STOP_EOF

chmod +x stop.sh

# 15. README - ažuriran za port 5433
cat > README.md << 'README_EOF'
# 🚀 CRM Demo - PostgreSQL (Port 5433)

Kompletan CRM sistem sa Vue 3, Node.js i PostgreSQL na portu 5433.

## 🏗️ Struktura Projekta
README_EOF
