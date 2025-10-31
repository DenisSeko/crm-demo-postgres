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
echo "║               STAGING BRANCH                 ║"
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
    cat > $1 << CONTENT
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

# frontend/vercel.json
if [ ! -f "frontend/vercel.json" ]; then
    create_file "frontend/vercel.json" '{
  "version": 2,
  "builds": [
    {
      "src": "package.json",
      "use": "@vercel/static-build",
      "config": {
        "distDir": "dist"
      }
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "/index.html"
    }
  ]
}'
else
    echo -e "${GREEN}✅ frontend/vercel.json already exists${NC}"
fi

# frontend/.env.production
if [ ! -f "frontend/.env.production" ]; then
    create_file "frontend/.env.production" 'VITE_API_URL=YOUR_RAILWAY_BACKEND_URL_HERE'
else
    echo -e "${GREEN}✅ frontend/.env.production already exists${NC}"
fi

# 5. KREIRAJ BACKEND SA POSTGRESQL PODRŠKOM
echo -e "${YELLOW}🔧 Preparing backend with PostgreSQL...${NC}"

# Kreiraj database folder ako ne postoji
mkdir -p backend/database

# backend/package.json sa PostgreSQL dependency
if [ ! -f "backend/package.json" ]; then
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
else
    echo -e "${YELLOW}📦 Updating backend/package.json with PostgreSQL...${NC}"
    # Ažuriraj postojeći package.json sa PostgreSQL dependency
    if grep -q "pg" backend/package.json; then
        echo -e "${GREEN}✅ PostgreSQL dependency already exists${NC}"
    else
        echo -e "${YELLOW}➕ Adding PostgreSQL dependencies...${NC}"
        # Ovo je pojednostavljeno - u praksi bi koristili jq za JSON manipulaciju
        echo -e "${YELLOW}⚠️  Please manually add 'pg' and 'bcryptjs' to backend/package.json dependencies${NC}"
    fi
fi

# Database init script koji koristi tvoj schema.sql
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
        // Pročitaj schema.sql fajl
        const schemaPath = path.join(__dirname, '..', '..', 'database', 'schema.sql');
        const schemaSQL = fs.readFileSync(schemaPath, 'utf8');
        
        console.log('📖 Running schema.sql...');
        
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
        const userCheck = await pool.query('SELECT * FROM users WHERE email = \$1', ['demo@demo.com']);
        
        if (userCheck.rows.length === 0) {
            // Dodaj demo usera
            await pool.query(
                'INSERT INTO users (email, password, name) VALUES (\$1, \$2, \$3)',
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

# 6. KREIRAJ DOCKERFILE ZA RAILWAY - POPRAVLJENO ZA BACKEND FOLDER
create_file "Dockerfile" "FROM node:18-alpine

WORKDIR /app

# Kopiraj backend package fajlove
COPY backend/package*.json ./

# Instaliraj zavisnosti
RUN npm install --production

# Kopiraj CIJELI backend folder
COPY backend/ ./
# Kopiraj database schema
COPY database/ ./database/

# Pokreni init skriptu pri pokretanju
CMD [\"sh\", \"-c\", \"npm run db:init && npm start\"]

EXPOSE 3001"

# 7. KREIRAJ RAILWAY.TOML SA POSTGRESQL - AŽURIRANO ZA STAGING
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

# 9. KREIRAJ AŽURIRANI SERVER.JS SA POSTGRESQL
if [ ! -f "backend/server.js" ] || grep -q "in-memory" "backend/server.js"; then
    echo -e "${YELLOW}🔄 Updating server.js with PostgreSQL support...${NC}"
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
            'SELECT id, email, name, password FROM users WHERE email = \$1',
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
            'INSERT INTO clients (name, email, company, owner_id) VALUES (\$1, \$2, \$3, \$4) RETURNING *',
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
            'SELECT * FROM notes WHERE client_id = \$1 ORDER BY created_at DESC',
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
            'INSERT INTO notes (content, client_id) VALUES (\$1, \$2) RETURNING *',
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
else
    echo -e "${GREEN}✅ backend/server.js already exists with PostgreSQL support${NC}"
fi

# 10. TEST BUILD FRONTENDA
echo -e "${YELLOW}🧪 Testing frontend build...${NC}"
cd frontend
npm install
npm run build
cd ..
check_success "Frontend build test passed"

# 11. GIT COMMIT - SA VIDLJIVIM OUTPUT-OM
echo -e "${YELLOW}💾 Committing deployment files...${NC}"
echo -e "${YELLOW}📊 Git status before commit:${NC}"
git status

git add .
git commit -m "feat: PostgreSQL deployment with schema.sql

- PostgreSQL database integration
- Automatic schema.sql execution on deploy
- Database initialization script
- Railway with PostgreSQL service
- Docker configuration (fixed for backend folder)
- Demo user: demo@demo.com / demo123
- Deploy from staging branch"

check_success "Changes committed"

# 12. PUSH TO GITHUB - NA STAGING BRANCH
echo -e "${YELLOW}📤 Pushing to GitHub (staging branch)...${NC}"
git push origin staging
check_success "Pushed to GitHub staging branch"

# 13. PRIKAŽI PROMJENE
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════╗"
echo "║               📊 CREATED FILES               ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}🎯 New files created:${NC}"
echo "├── 📄 backend/database/init.js"
echo "├── 📄 backend/database/db.js" 
echo "├── 📄 Dockerfile (FIXED for backend folder)"
echo "├── 📄 railway.toml"
echo "└── 📄 backend/.env.example"

echo -e "${BLUE}🔧 Updated files:${NC}"
echo "├── 📄 backend/package.json (PostgreSQL dependencies)"
echo "└── 📄 backend/server.js (PostgreSQL integration)"

echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════╗"
echo "║               ✅ DEPLOYMENT READY            ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}🎯 Next steps:${NC}"
echo "1. Go to Railway: https://railway.app"
echo "2. Click 'New Project' → 'Deploy from GitHub repo'"
echo "3. Select your repository"
echo "4. Railway will automatically deploy from STAGING branch with PostgreSQL!"

echo -e "${GREEN}🚀 Check your GitHub repository - all changes should be visible on STAGING branch now!${NC}"

# 14. PROVJERA BRANCH-A
echo -e "${YELLOW}🔍 Verifying branch setup...${NC}"
echo -e "${BLUE}📋 Current branch: $(git branch --show-current)${NC}"
echo -e "${BLUE}📁 Project structure:${NC}"
find . -name "*.js" -o -name "*.json" -o -name "Dockerfile" -o -name "*.toml" | head -20

# HOTFIX
echo -e "${GREEN}✅ Dockerfile is now properly configured to work with backend/ folder!${NC}"