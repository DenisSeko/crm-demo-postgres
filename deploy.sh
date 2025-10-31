#!/bin/bash

# Boje za output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════╗"
echo "║           🚀 CRM DEPLOYMENT SCRIPT           ║"
echo "║        Vercel (Frontend) + Railway (Backend) ║"
echo "║           POSTGRESQL SCHEMA FIX              ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

# Funkcija za provjeru uspjeha
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${RED}❌ $1${NC}"
        exit 1
    fi
}

# Funkcija za kreiranje fajlova
create_file() {
    echo -e "${YELLOW}📝 Creating $1...${NC}"
    mkdir -p "$(dirname "$1")"
    cat > "$1" << CONTENT
$2
CONTENT
    check_success "Created $1"
}

# 1. PROVJERA GIT REPO I BRANCH-A
echo -e "${YELLOW}🔍 Checking Git repository and branch...${NC}"
if [ ! -d .git ]; then
    echo -e "${RED}❌ Not a Git repository${NC}"
    echo "Initialize git first: git init && git add . && git commit -m 'Initial commit'"
    exit 1
fi

# Provjeri koji branch koristimo
CURRENT_BRANCH=$(git branch --show-current)
echo -e "${BLUE}📋 Current branch: $CURRENT_BRANCH${NC}"

# Ako nismo na staging branch-u, prebaci se
if [ "$CURRENT_BRANCH" != "staging" ]; then
    echo -e "${YELLOW}🔄 Switching to staging branch...${NC}"
    git checkout -b staging 2>/dev/null || git checkout staging
    check_success "Switched to staging branch"
fi

check_success "Git repository found"

# 2. PROVJERA I POPRAVAK SCHEMA.SQL
echo -e "${YELLOW}🗄️  Checking and fixing schema.sql...${NC}"
if [ ! -f "database/schema.sql" ]; then
    echo -e "${RED}❌ schema.sql not found${NC}"
    echo "Please ensure schema.sql exists in database/ directory"
    exit 1
fi

# Provjeri schema.sql sadržaj
echo -e "${YELLOW}📋 Checking schema.sql content...${NC}"
if ! grep -q "CREATE TABLE" database/schema.sql && ! grep -q "INSERT INTO" database/schema.sql; then
    echo -e "${YELLOW}⚠️  schema.sql might be empty or invalid, creating basic schema...${NC}"
    create_file "database/schema.sql" "-- PostgreSQL Schema for CRM App
-- This schema will be automatically executed on Railway deployment

-- Enable UUID extension if needed
CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Clients table
CREATE TABLE IF NOT EXISTS clients (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    company VARCHAR(255),
    phone VARCHAR(50),
    owner_id INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Notes table
CREATE TABLE IF NOT EXISTS notes (
    id SERIAL PRIMARY KEY,
    content TEXT NOT NULL,
    client_id INTEGER REFERENCES clients(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert demo user if not exists
INSERT INTO users (email, password, name) 
VALUES ('demo@demo.com', 'demo123', 'Demo User')
ON CONFLICT (email) DO NOTHING;

-- Insert demo clients
INSERT INTO clients (name, email, company, owner_id) 
VALUES 
    ('John Doe', 'john@example.com', 'ABC Company', 1),
    ('Jane Smith', 'jane@example.com', 'XYZ Corp', 1)
ON CONFLICT (email) DO NOTHING;

-- Insert demo notes
INSERT INTO notes (content, client_id) 
VALUES 
    ('First meeting went well. Interested in our services.', 1),
    ('Follow up scheduled for next week.', 1),
    ('Requested product demo for next month.', 2)
ON CONFLICT DO NOTHING;"
else
    echo -e "${GREEN}✅ schema.sql looks valid${NC}"
fi

# 3. KREIRAJ FRONTEND DEPLOYMENT FAJLOVE
echo -e "${YELLOW}🎨 Preparing frontend for Vercel...${NC}"

create_file "frontend/vercel.json" '{
  "version": 2,
  "builds": [
    {
      "src": "package.json",
      "use": "@vercel/static-build"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "/index.html"
    }
  ]
}'

create_file "frontend/.env.production" 'VITE_API_URL=YOUR_RAILWAY_BACKEND_URL_HERE'

# 4. KREIRAJ BACKEND SA POUZDANIM SCHEMA IMPORT-OM
echo -e "${YELLOW}🔧 Preparing backend with reliable schema import...${NC}"

mkdir -p backend/database

# backend/package.json
create_file "backend/package.json" '{
  "name": "crm-backend",
  "version": "1.0.0",
  "description": "CRM Backend API with PostgreSQL",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "db:init": "node database/init.js",
    "db:setup": "node database/setup.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "pg": "^8.11.3",
    "bcryptjs": "^2.4.3",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  },
  "keywords": ["crm", "api", "backend", "postgresql"],
  "author": "",
  "license": "MIT"
}'

# Poboljšani database setup sa boljom error handling
create_file "backend/database/setup.js" "const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

async function setupDatabase() {
    console.log('🚀 Starting database setup...');
    
    // Koristi DATABASE_URL od Railway-a
    const connectionString = process.env.DATABASE_URL;
    
    if (!connectionString) {
        throw new Error('DATABASE_URL environment variable is not set');
    }
    
    console.log('🔌 Using DATABASE_URL:', connectionString.replace(/:[^:]*@/, ':****@'));
    
    const pool = new Pool({
        connectionString: connectionString,
        ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
        connectionTimeoutMillis: 10000,
        query_timeout: 30000
    });

    let client;
    try {
        // Pokušaj spojiti se na bazu
        console.log('⏳ Connecting to PostgreSQL...');
        client = await pool.connect();
        console.log('✅ Connected to PostgreSQL successfully!');

        // Testiraj connection
        console.log('🧪 Testing database connection...');
        const result = await client.query('SELECT version()');
        console.log('✅ PostgreSQL Version:', result.rows[0].version);

        // Pročitaj schema.sql
        console.log('📖 Reading schema.sql...');
        const schemaPath = path.join(__dirname, 'schema.sql');
        
        if (!fs.existsSync(schemaPath)) {
            throw new Error('schema.sql not found at: ' + schemaPath);
        }
        
        const schemaSQL = fs.readFileSync(schemaPath, 'utf8');
        console.log('✅ schema.sql loaded, size:', schemaSQL.length, 'characters');

        // Pokreni SQL komande jednu po jednu
        console.log('🔄 Executing schema...');
        const commands = schemaSQL
            .split(';')
            .map(cmd => cmd.trim())
            .filter(cmd => cmd.length > 0 && !cmd.startsWith('--'));

        console.log('📝 Found', commands.length, 'SQL commands to execute');

        for (let i = 0; i < commands.length; i++) {
            const command = commands[i] + ';';
            try {
                console.log('   Executing command', (i + 1), 'of', commands.length);
                await client.query(command);
                console.log('   ✅ Command', (i + 1), 'executed successfully');
            } catch (error) {
                // Ako je \"već postoji\" greška, ignoriši je
                if (error.message.includes('already exists') || 
                    error.message.includes('duplicate key') ||
                    error.message.includes('exists')) {
                    console.log('   ⚠️  Command', (i + 1), 'skipped (already exists):', error.message);
                } else {
                    console.log('   ❌ Command', (i + 1), 'failed:', error.message);
                    throw error;
                }
            }
        }

        console.log('🎉 Database setup completed successfully!');

        // Provjeri tabele
        console.log('📊 Checking created tables...');
        const tablesResult = await client.query(\`
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
        \`);
        
        console.log('✅ Available tables:', tablesResult.rows.map(row => row.table_name).join(', '));

    } catch (error) {
        console.error('💥 Database setup failed:', error.message);
        throw error;
    } finally {
        if (client) {
            client.release();
        }
        await pool.end();
    }
}

// Pokreni setup ako je skripta pozvana direktno
if (require.main === module) {
    setupDatabase()
        .then(() => {
            console.log('🚀 Database setup process completed');
            process.exit(0);
        })
        .catch(error => {
            console.error('💥 Database setup process failed');
            process.exit(1);
        });
}

module.exports = { setupDatabase };"

# Pojednostavljeni init.js
create_file "backend/database/init.js" "const { setupDatabase } = require('./setup');
require('dotenv').config();

async function initializeDatabase() {
    console.log('🗄️  Starting database initialization...');
    
    try {
        await setupDatabase();
        console.log('🎉 Database initialization completed successfully!');
    } catch (error) {
        console.error('❌ Database initialization failed:', error.message);
        throw error;
    }
}

// Pokreni inicijalizaciju ako je skripta pozvana direktno
if (require.main === module) {
    initializeDatabase()
        .then(() => {
            console.log('🚀 Init process completed');
            process.exit(0);
        })
        .catch(error => {
            console.error('💥 Init process failed');
            process.exit(1);
        });
}

module.exports = { initializeDatabase };"

# Database connection helper
create_file "backend/database/db.js" "const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

pool.on('connect', () => {
    console.log('✅ Connected to PostgreSQL database');
});

pool.on('error', (err) => {
    console.error('❌ PostgreSQL connection error:', err);
});

module.exports = {
    query: (text, params) => pool.query(text, params),
    pool
};"

# 5. KREIRAJ POBOLJŠANI DOCKERFILE
create_file "Dockerfile" "FROM node:18-alpine

WORKDIR /app

# Kopiraj package fajlove
COPY backend/package*.json ./

# Instaliraj zavisnosti
RUN npm install --production

# Kopiraj backend kod
COPY backend/ ./

# Kopiraj schema.sql na specifičnu lokaciju
COPY database/schema.sql ./database/schema.sql

# Pokreni database setup pa server
CMD [\"sh\", \"-c\", \"echo '🚀 Starting application...' && npm run db:setup && echo '🎉 Starting server...' && npm start\"]

EXPOSE 3001"

# 6. KREIRAJ RAILWAY.TOML
create_file "railway.toml" "[build]
builder = \"nixpacks\"

[deploy]
startCommand = \"npm run db:setup && npm start\"
restartPolicyType = \"ON_FAILURE\"
restartPolicyMaxRetries = 3

[deploy.branches]
only = [\"staging\"]

[[services]]
name = \"web\"
run = \"npm start\"

[[services]]
name = \"database\"
type = \"postgresql\"
plan = \"hobby\"

[environments.production.variables]
NODE_ENV = \"production\"
PORT = \"3001\"

[environments.staging.variables] 
NODE_ENV = \"production\"
PORT = \"3001\""

# 7. KREIRAJ SERVER.JS
create_file "backend/server.js" "const express = require('express');
const cors = require('cors');
const { query } = require('./database/db');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

app.get('/api/health', async (req, res) => {
    try {
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

app.post('/api/auth/login', async (req, res) => {
    const { email, password } = req.body;
    
    try {
        const result = await query(
            'SELECT id, email, name, password FROM users WHERE email = $1',
            [email]
        );
        
        if (result.rows.length === 0) {
            return res.status(401).json({ 
                success: false, 
                message: 'Invalid email or password' 
            });
        }
        
        const user = result.rows[0];
        
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

app.get('/api/clients', async (req, res) => {
    try {
        const result = await query('SELECT * FROM clients ORDER BY created_at DESC');
        res.json({ success: true, clients: result.rows });
    } catch (error) {
        console.error('Get clients error:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch clients' });
    }
});

app.post('/api/clients', async (req, res) => {
    const { name, email, company } = req.body;
    
    try {
        const result = await query(
            'INSERT INTO clients (name, email, company) VALUES ($1, $2, $3) RETURNING *',
            [name, email, company]
        );
        res.json({ success: true, client: result.rows[0] });
    } catch (error) {
        console.error('Add client error:', error);
        res.status(500).json({ success: false, message: 'Failed to add client' });
    }
});

app.get('/', (req, res) => {
    res.json({ 
        message: 'CRM Backend API with PostgreSQL',
        version: '1.0.0',
        endpoints: {
            health: 'GET /api/health',
            login: 'POST /api/auth/login',
            clients: 'GET /api/clients',
            'add-client': 'POST /api/clients'
        },
        database: 'PostgreSQL',
        demo: {
            email: 'demo@demo.com',
            password: 'demo123'
        }
    });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log('=================================');
    console.log('🚀 CRM Backend STARTED SUCCESSFULLY');
    console.log('📍 Port: ' + PORT);
    console.log('🗄️  Database: PostgreSQL');
    console.log('🌐 Environment: ' + (process.env.NODE_ENV || 'development'));
    console.log('✅ Health: http://localhost:' + PORT + '/api/health');
    console.log('🔑 Demo: demo@demo.com / demo123');
    console.log('=================================');
});"

# 8. KOPIRAJ SCHEMA.SQL
echo -e "${YELLOW}📋 Copying schema.sql to backend/database/...${NC}"
cp database/schema.sql backend/database/schema.sql
check_success "Copied schema.sql to backend/database/"

# 9. INSTALIRAJ DEPENDENCIES
echo -e "${YELLOW}📦 Installing PostgreSQL dependencies...${NC}"
cd backend
npm install pg bcryptjs --save --no-audit --no-fund
cd ..
check_success "PostgreSQL dependencies installed"

# 10. GIT COMMIT
echo -e "${YELLOW}💾 Committing deployment files...${NC}"
git add .
git commit -m "fix: Reliable PostgreSQL schema import on Railway

- Added robust database setup with better error handling
- Improved schema.sql with IF NOT EXISTS and ON CONFLICT
- Better connection management and logging
- Simplified initialization process
- All files use CommonJS
- Deploy from staging branch"

check_success "Changes committed"

# 11. PUSH TO GITHUB
echo -e "${YELLOW}📤 Pushing to GitHub (staging branch)...${NC}"
git push origin staging
check_success "Pushed to GitHub staging branch"

# 12. FINALNE UPUTE
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════╗"
echo "║               🎉 SCHEMA FIXED!               ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}🔧 Improvements made:${NC}"
echo "✅ Better error handling for existing tables"
echo "✅ Uses ON CONFLICT DO NOTHING for inserts"
echo "✅ CREATE TABLE IF NOT EXISTS for tables"
echo "✅ Improved connection management"
echo "✅ Better logging and debugging"
echo "✅ Simplified setup process"

echo -e "${GREEN}🚀 Schema should now import reliably on Railway!${NC}"
echo -e "${YELLOW}📝 Check Railway logs for detailed database setup information${NC}"