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
echo "║           POSTGRESQL + schema.sql            ║"
echo "║           DATABASE CONNECTION FIX            ║"
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

# 2. PROVJERA schema.sql
echo -e "${YELLOW}🗄️  Checking database schema...${NC}"
if [ ! -f "database/schema.sql" ]; then
    echo -e "${RED}❌ schema.sql not found${NC}"
    echo "Please ensure schema.sql exists in database/ directory"
    exit 1
fi
check_success "schema.sql found"

# 3. KREIRAJ FRONTEND DEPLOYMENT FAJLOVE
echo -e "${YELLOW}🎨 Preparing frontend for Vercel...${NC}"

# Ukloni stari vercel.json ako postoji
if [ -f "frontend/vercel.json" ]; then
    echo -e "${YELLOW}🗑️  Removing old vercel.json...${NC}"
    rm -f frontend/vercel.json
fi

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

# 4. KREIRAJ BACKEND SA DATABASE CONNECTION RETRY
echo -e "${YELLOW}🔧 Preparing backend with Database Connection Retry...${NC}"

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
    "db:wait": "node database/wait-for-db.js"
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

# Database wait script - Čeka da baza bude spremna
create_file "backend/database/wait-for-db.js" "const { Pool } = require('pg');
require('dotenv').config();

async function waitForDatabase() {
    console.log('⏳ Waiting for PostgreSQL database to be ready...');
    
    const pool = new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
        // Kratki timeout za brže failanje
        connectionTimeoutMillis: 5000,
        query_timeout: 5000
    });

    let attempts = 0;
    const maxAttempts = 30; // 30 pokušaja = 2.5 minuta
    
    while (attempts < maxAttempts) {
        try {
            attempts++;
            console.log('🔌 Attempting database connection...', 'Attempt', attempts, 'of', maxAttempts);
            
            // Pokušaj spojiti se na bazu
            const client = await pool.connect();
            console.log('✅ Database connection successful!');
            
            // Testiraj connection
            await client.query('SELECT NOW()');
            console.log('✅ Database is responding to queries');
            
            client.release();
            await pool.end();
            
            console.log('🎉 Database is ready for initialization!');
            return true;
            
        } catch (error) {
            console.log('❌ Database not ready yet:', error.message);
            
            if (attempts >= maxAttempts) {
                console.log('💥 Max connection attempts reached. Database might not be available.');
                await pool.end();
                return false;
            }
            
            // Čekaj 5 sekundi prije sljedećeg pokušaja
            console.log('⏰ Waiting 5 seconds before retry...');
            await new Promise(resolve => setTimeout(resolve, 5000));
        }
    }
    
    await pool.end();
    return false;
}

// Pokreni čekanje ako je skripta pozvana direktno
if (require.main === module) {
    waitForDatabase()
        .then(success => {
            if (success) {
                console.log('🚀 Proceeding with database initialization...');
                process.exit(0);
            } else {
                console.log('💥 Cannot connect to database. Exiting.');
                process.exit(1);
            }
        })
        .catch(error => {
            console.error('💥 Error waiting for database:', error);
            process.exit(1);
        });
}

module.exports = { waitForDatabase };"

# Database init script - SA RETRY LOGIKOM
create_file "backend/database/init.js" "const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
const { waitForDatabase } = require('./wait-for-db');
require('dotenv').config();

async function initializeDatabase() {
    console.log('🗄️  Starting PostgreSQL database initialization...');
    
    // Prvo pričekaj da baza bude spremna
    const dbReady = await waitForDatabase();
    if (!dbReady) {
        throw new Error('Database is not ready for initialization');
    }
    
    console.log('✅ Database is ready, proceeding with schema setup...');
    
    const pool = new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
    });

    try {
        // Pronađi schema.sql
        const schemaPath = path.join(__dirname, 'schema.sql');
        console.log('🔍 Looking for schema.sql at:', schemaPath);
        
        if (!fs.existsSync(schemaPath)) {
            throw new Error('schema.sql not found at: ' + schemaPath);
        }
        
        const schemaSQL = fs.readFileSync(schemaPath, 'utf8');
        console.log('✅ Found schema.sql, running database setup...');
        
        // Podijeli SQL komande i pokreni ih jednu po jednu
        const sqlCommands = schemaSQL
            .split(';')
            .map(cmd => cmd.trim())
            .filter(cmd => cmd.length > 0);
        
        console.log('📝 Found', sqlCommands.length, 'SQL commands to execute');
        
        for (let i = 0; i < sqlCommands.length; i++) {
            const command = sqlCommands[i] + ';';
            try {
                console.log('🔄 Executing command', (i + 1), 'of', sqlCommands.length);
                await pool.query(command);
                console.log('✅ Command', (i + 1), 'executed successfully');
            } catch (error) {
                // Ako je greška \"relation already exists\", ignoriši je
                if (error.message.includes('already exists')) {
                    console.log('⚠️  Table already exists, continuing...');
                } else {
                    throw error;
                }
            }
        }
        
        console.log('✅ All SQL commands executed successfully');
        
        // Dodaj demo podatke
        await seedDemoData(pool);
        
        console.log('🎉 Database initialization completed successfully!');
        
    } catch (error) {
        console.error('❌ Database initialization error:', error.message);
        throw error;
    } finally {
        await pool.end();
    }
}

async function seedDemoData(pool) {
    try {
        console.log('🌱 Seeding demo data...');
        
        // Provjeri da li već postoje demo podaci
        const userCheck = await pool.query('SELECT * FROM users WHERE email = $1', ['demo@demo.com']);
        
        if (userCheck.rows.length === 0) {
            // Dodaj demo usera
            await pool.query(
                'INSERT INTO users (email, password, name) VALUES ($1, $2, $3)',
                ['demo@demo.com', 'demo123', 'Demo User']
            );
            console.log('👤 Demo user created: demo@demo.com / demo123');
        } else {
            console.log('👤 Demo user already exists');
        }
        
    } catch (error) {
        console.log('⚠️  Could not seed demo data:', error.message);
    }
}

// Pokreni inicijalizaciju ako je skripta pozvana direktno
if (require.main === module) {
    initializeDatabase()
        .then(() => {
            console.log('🚀 Database initialization process completed');
            process.exit(0);
        })
        .catch(error => {
            console.error('💥 Database initialization failed:', error);
            process.exit(1);
        });
}

module.exports = { initializeDatabase };"

# Database connection helper
create_file "backend/database/db.js" "const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
    // Retry logika za production
    ...(process.env.NODE_ENV === 'production' && {
        connectionTimeoutMillis: 10000,
        idleTimeoutMillis: 30000,
        max: 20
    })
});

// Test connection on startup
pool.on('connect', () => {
    console.log('✅ Connected to PostgreSQL database');
});

pool.on('error', (err) => {
    console.error('❌ PostgreSQL connection error:', err);
});

// Funkcija za retry connection
const queryWithRetry = async (text, params, retries = 3) => {
    for (let i = 0; i < retries; i++) {
        try {
            return await pool.query(text, params);
        } catch (error) {
            if (i === retries - 1) throw error;
            console.log('🔄 Query failed, retrying...', error.message);
            await new Promise(resolve => setTimeout(resolve, 1000 * (i + 1)));
        }
    }
};

module.exports = {
    query: queryWithRetry,
    pool
};"

# 5. KREIRAJ DOCKERFILE SA BOLJIM START SEKVENCAMA
create_file "Dockerfile" "FROM node:18-alpine

WORKDIR /app

# Kopiraj backend package fajlove
COPY backend/package*.json ./

# Instaliraj zavisnosti
RUN npm install --production

# Kopiraj CIJELI backend folder
COPY backend/ ./

# Kopiraj database schema
COPY database/schema.sql ./database/schema.sql

# Pokreni wait-for-db PRVO, pa init, pa server
CMD [\"sh\", \"-c\", \"echo '🚀 Starting application...' && npm run db:wait && echo '✅ Database ready, running init...' && npm run db:init && echo '🎉 Starting server...' && npm start\"]

EXPOSE 3001"

# 6. KREIRAJ RAILWAY.TOML SA BOLJIM START COMMAND
create_file "railway.toml" "[build]
builder = \"nixpacks\"

[deploy]
startCommand = \"npm run db:wait && npm run db:init && npm start\"
restartPolicyType = \"ON_FAILURE\"
restartPolicyMaxRetries = 3

# Deploy samo sa staging branch-a
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

# 7. KREIRAJ ENVIRONMENT FAJLOVE
create_file "backend/.env.example" "# PostgreSQL Database (Railway will auto-provide DATABASE_URL)
DATABASE_URL=postgresql://username:password@localhost:5432/crm_database

# Application
NODE_ENV=development
PORT=3001
JWT_SECRET=your-jwt-secret-here

# Railway will automatically provide DATABASE_URL"

# 8. KREIRAJ SERVER.JS SA GRACEFUL START
create_file "backend/server.js" "const express = require('express');
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

// Ostali endpointovi ostaju isti...
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

// Simple endpoints za sada
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

// Root endpoint
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
});"

# 9. KOPIRAJ SCHEMA.SQL
echo -e "${YELLOW}📋 Ensuring schema.sql is in backend folder...${NC}"
cp database/schema.sql backend/database/schema.sql
check_success "Copied schema.sql to backend/database/"

# 10. TEST COMMONJS SYNTAX
echo -e "${YELLOW}🧪 Testing CommonJS syntax...${NC}"
if node -c backend/server.js && node -c backend/database/init.js && node -c backend/database/db.js && node -c backend/database/wait-for-db.js; then
    echo -e "${GREEN}✅ All CommonJS files have valid syntax${NC}"
else
    echo -e "${RED}❌ Syntax error in CommonJS files${NC}"
    exit 1
fi

# 11. INSTALIRAJ DEPENDENCIES
echo -e "${YELLOW}📦 Installing PostgreSQL dependencies...${NC}"
cd backend
npm install pg bcryptjs --save --no-audit --no-fund
cd ..
check_success "PostgreSQL dependencies installed"

# 12. GIT COMMIT
echo -e "${YELLOW}💾 Committing deployment files...${NC}"
git add .
git commit -m "fix: Database connection with retry logic

- Added wait-for-db.js to wait for PostgreSQL to be ready
- Database init now waits for connection before running schema
- Added retry logic for database queries
- Improved Dockerfile start sequence
- All files use CommonJS
- Deploy from staging branch"

check_success "Changes committed"

# 13. PUSH TO GITHUB
echo -e "${YELLOW}📤 Pushing to GitHub (staging branch)...${NC}"
git push origin staging
check_success "Pushed to GitHub staging branch"

# 14. FINALNE UPUTE
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════╗"
echo "║               🎉 DATABASE FIXED!             ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}🔧 What was fixed:${NC}"
echo "✅ Added wait-for-db.js - čeka da PostgreSQL bude spreman"
echo "✅ Database init sada prvo čeka connection prije pokretanja schema.sql"
echo "✅ Retry logika za database queries"
echo "✅ Poboljšana start sekvenca u Dockerfile"
echo "✅ Max 30 pokušaja (2.5 minuta) za database connection"

echo -e "${GREEN}🚀 Deployment should now handle database startup delays!${NC}"
echo -e "${YELLOW}📝 Note: Railway PostgreSQL može trebati 1-2 minute da se pokrene${NC}"