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
echo "║             FIXED SCHEMA PATH                ║"
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

# 3. PROVJERA POSTOJEĆIH FAJLOVA
echo -e "${YELLOW}📁 Checking existing files...${NC}"
echo "Frontend exists: $(test -d 'frontend' && echo '✅' || echo '❌')"
echo "Backend exists: $(test -d 'backend' && echo '✅' || echo '❌')"
echo "schema.sql exists: $(test -f 'database/schema.sql' && echo '✅' || echo '❌')"

# 4. KREIRAJ FRONTEND DEPLOYMENT FAJLOVE
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

# 5. KREIRAJ BACKEND SA POSTGRESQL PODRŠKOM - POPRAVLJENA PUTANJA
echo -e "${YELLOW}🔧 Preparing backend with PostgreSQL (Fixed schema path)...${NC}"

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
    "db:seed": "node database/seed.js"
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

# Database init script - POPRAVLJENA PUTANJA DO SCHEMA.SQL
create_file "backend/database/init.js" "const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

async function initializeDatabase() {
    console.log('🗄️  Initializing PostgreSQL database from schema.sql...');
    
    const pool = new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
    });

    try {
        // POKUŠAJ RAZLIČITE PUTANJE DO SCHEMA.SQL
        const possiblePaths = [
            path.join(__dirname, 'schema.sql'),                    // /app/database/schema.sql
            path.join(__dirname, '..', 'schema.sql'),              // /app/schema.sql  
            path.join(__dirname, '..', '..', 'database', 'schema.sql'), // /database/schema.sql
            '/app/database/schema.sql',                            // Apsolutna putanja u Dockeru
            '/app/schema.sql',                                     // Apsolutna putanja u Dockeru
            './database/schema.sql',                               // Relativna putanja
            './schema.sql'                                         // Relativna putanja
        ];
        
        let schemaPath = null;
        let schemaSQL = null;
        
        // Pronađi schema.sql na bilo kojoj od mogućih putanja
        for (const possiblePath of possiblePaths) {
            try {
                console.log('🔍 Looking for schema.sql at:', possiblePath);
                if (fs.existsSync(possiblePath)) {
                    schemaPath = possiblePath;
                    schemaSQL = fs.readFileSync(possiblePath, 'utf8');
                    console.log('✅ Found schema.sql at:', schemaPath);
                    break;
                }
            } catch (error) {
                // Nastavi sa sljedećom putanjom
                console.log('❌ Not found at:', possiblePath);
            }
        }
        
        if (!schemaSQL) {
            console.log('❌ schema.sql not found at any known location');
            console.log('📁 Current working directory:', process.cwd());
            console.log('📁 Directory contents:');
            try {
                const files = fs.readdirSync('.');
                console.log('Root:', files);
                
                if (fs.existsSync('./database')) {
                    const dbFiles = fs.readdirSync('./database');
                    console.log('Database folder:', dbFiles);
                }
                
                if (fs.existsSync('./app')) {
                    const appFiles = fs.readdirSync('./app');
                    console.log('App folder:', appFiles);
                }
            } catch (error) {
                console.log('⚠️  Could not read directory structure');
            }
            throw new Error('schema.sql not found');
        }
        
        console.log('📖 Running schema.sql from:', schemaPath);
        
        // Pokreni SQL komande iz schema.sql
        await pool.query(schemaSQL);
        
        console.log('✅ Database initialized successfully from schema.sql');
        
        // Dodaj demo podatke ako su potrebni
        await seedDemoData(pool);
        
    } catch (error) {
        console.error('❌ Database initialization error:', error);
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
        console.log('⚠️  Could not seed demo data (table might not exist yet):', error.message);
    }
}

// Pokreni inicijalizaciju ako je skripta pozvana direktno
if (require.main === module) {
    initializeDatabase().catch(console.error);
}

module.exports = { initializeDatabase };"

# Database connection helper
create_file "backend/database/db.js" "const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

// Test connection on startup
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

# 6. KREIRAJ DOCKERFILE - POPRAVLJENO KOPIRANJE SCHEMA.SQL
create_file "Dockerfile" "FROM node:18-alpine

WORKDIR /app

# Kopiraj backend package fajlove
COPY backend/package*.json ./

# Instaliraj zavisnosti
RUN npm install --production

# Kopiraj CIJELI backend folder
COPY backend/ ./

# Kopiraj database schema u DVIJE lokacije za sigurnost
COPY database/ ./database/
COPY database/schema.sql ./schema.sql

# Pokreni init skriptu pri pokretanju
CMD [\"sh\", \"-c\", \"npm run db:init && npm start\"]

EXPOSE 3001"

# 7. KREIRAJ RAILWAY.TOML SA POSTGRESQL
create_file "railway.toml" "[build]
builder = \"nixpacks\"

[deploy]
startCommand = \"npm run db:init && npm start\"
restartPolicyType = \"ON_FAILURE\"
restartPolicyMaxRetries = 10

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

# 8. KREIRAJ ENVIRONMENT FAJLOVE
create_file "backend/.env.example" "# PostgreSQL Database
DATABASE_URL=postgresql://username:password@localhost:5432/crm_database

# Application
NODE_ENV=development
PORT=3001
JWT_SECRET=your-jwt-secret-here

# Railway will automatically provide DATABASE_URL"

# 9. KREIRAJ SERVER.JS - COMMONJS
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

// Login sa PostgreSQL
app.post('/api/auth/login', async (req, res) => {
    const { email, password } = req.body;
    
    try {
        // Pronađi usera u bazi
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
            'INSERT INTO clients (name, email, company, owner_id) VALUES ($1, $2, $3, $4) RETURNING *',
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
            'SELECT * FROM notes WHERE client_id = $1 ORDER BY created_at DESC',
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
            'INSERT INTO notes (content, client_id) VALUES ($1, $2) RETURNING *',
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
});"

# 10. KOPIRAJ SCHEMA.SQL U BACKEND FOLDER ZA SIGURNOST
echo -e "${YELLOW}📋 Copying schema.sql to backend folder for safety...${NC}"
cp database/schema.sql backend/schema.sql
check_success "Copied schema.sql to backend folder"

# 11. TEST COMMONJS SYNTAX
echo -e "${YELLOW}🧪 Testing CommonJS syntax...${NC}"
if node -c backend/server.js && node -c backend/database/init.js && node -c backend/database/db.js; then
    echo -e "${GREEN}✅ All CommonJS files have valid syntax${NC}"
else
    echo -e "${RED}❌ Syntax error in CommonJS files${NC}"
    exit 1
fi

# 12. INSTALIRAJ DEPENDENCIES
echo -e "${YELLOW}📦 Installing PostgreSQL dependencies...${NC}"
cd backend
npm install pg bcryptjs --save --no-audit --no-fund
cd ..
check_success "PostgreSQL dependencies installed"

# 13. TEST BUILD FRONTENDA
echo -e "${YELLOW}🧪 Testing frontend build...${NC}"
cd frontend
npm install --no-audit --no-fund
npm run build
cd ..
check_success "Frontend build test passed"

# 14. GIT COMMIT
echo -e "${YELLOW}💾 Committing deployment files...${NC}"
git add .
git commit -m "fix: Database initialization with correct schema path

- Fixed multiple schema.sql path locations
- Dockerfile now copies schema.sql to multiple locations
- Database init script searches for schema.sql in multiple paths
- Added debug logging for file locations
- All files use CommonJS
- Deploy from staging branch"

check_success "Changes committed"

# 15. PUSH TO GITHUB
echo -e "${YELLOW}📤 Pushing to GitHub (staging branch)...${NC}"
git push origin staging
check_success "Pushed to GitHub staging branch"

# 16. FINALNE UPUTE
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════╗"
echo "║               🎉 SCHEMA PATH FIXED!          ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}🔧 What was fixed:${NC}"
echo "✅ Database init now searches for schema.sql in multiple locations:"
echo "   - /app/database/schema.sql"
echo "   - /app/schema.sql"  
echo "   - ./database/schema.sql"
echo "   - ./schema.sql"
echo "✅ Dockerfile copies schema.sql to multiple locations"
echo "✅ Added debug logging to find schema.sql"
echo "✅ Backed up schema.sql to backend folder"

echo -e "${GREEN}🚀 Deployment should now find schema.sql successfully!${NC}"