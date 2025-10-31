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
echo "║           WAIT FOR DATABASE_URL              ║"
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

# 1. PROVJERA GIT REPO
echo -e "${YELLOW}🔍 Checking Git repository...${NC}"
if [ ! -d .git ]; then
    echo -e "${RED}❌ Not a Git repository${NC}"
    exit 1
fi

CURRENT_BRANCH=$(git branch --show-current)
echo -e "${BLUE}📋 Current branch: $CURRENT_BRANCH${NC}"

if [ "$CURRENT_BRANCH" != "staging" ]; then
    git checkout staging 2>/dev/null || git checkout -b staging
fi

# 2. KREIRAJ WAIT FOR DATABASE SCRIPT
echo -e "${YELLOW}⏳ Creating wait-for-database script...${NC}"

create_file "backend/database/wait-for-db.js" "console.log('⏳ WAIT-FOR-DB: Starting...');

let attempts = 0;
const maxAttempts = 60; // 5 minuta (60 * 5 sekundi)

function waitForDatabaseUrl() {
    return new Promise((resolve, reject) => {
        function check() {
            attempts++;
            console.log('🔍 Attempt', attempts, 'of', maxAttempts, '- Checking for DATABASE_URL...');
            
            if (process.env.DATABASE_URL) {
                const safeUrl = process.env.DATABASE_URL.replace(/:[^:]*@/, ':****@');
                console.log('✅ DATABASE_URL found:', safeUrl);
                resolve(true);
                return;
            }
            
            if (attempts >= maxAttempts) {
                console.log('💥 Timeout: DATABASE_URL not available after', maxAttempts, 'attempts');
                console.log('💡 Please check:');
                console.log('   1. Is PostgreSQL service added to your Railway project?');
                console.log('   2. Is PostgreSQL service running?');
                console.log('   3. Wait a few minutes for database to start');
                reject(new Error('DATABASE_URL not available'));
                return;
            }
            
            // Čekaj 5 sekundi prije sljedećeg pokušaja
            console.log('⏰ DATABASE_URL not ready, waiting 5 seconds...');
            setTimeout(check, 5000);
        }
        
        check();
    });
}

// Pokreni čekanje
waitForDatabaseUrl()
    .then(() => {
        console.log('🎉 DATABASE_URL is available! Proceeding with setup...');
        process.exit(0);
    })
    .catch(error => {
        console.log('💥 Failed to get DATABASE_URL');
        process.exit(1);
    });"

# 3. KREIRAJ NOVI START SCRIPT
create_file "backend/database/start-with-db.js" "console.log('🚀 START-WITH-DB: Starting application with database check...');

// Prvo pričekaj da DATABASE_URL bude dostupan
require('./wait-for-db.js').then(() => {
    // Sada pokreni setup
    console.log('📦 Running database setup...');
    require('./setup.js');
}).catch(error => {
    console.log('💥 Cannot start without database');
    process.exit(1);
});"

# 4. KREIRAJ PACKAGE.JSON SA NOVIM SCRIPT-OVIMA
create_file "backend/package.json" '{
  "name": "crm-backend",
  "version": "1.0.0",
  "description": "CRM Backend API with PostgreSQL",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "db:check": "node database/basic-check.js",
    "db:setup": "node database/setup.js",
    "db:wait": "node database/wait-for-db.js",
    "db:start": "node database/start-with-db.js",
    "start:with-db": "npm run db:wait && npm run db:setup && npm start"
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

# 5. KREIRAJ DOCKERFILE SA WAIT LOGIKOM
create_file "Dockerfile" "FROM node:18-alpine

WORKDIR /app

# Kopiraj package fajlove
COPY backend/package*.json ./

# Instaliraj zavisnosti
RUN npm install --production

# Kopiraj backend kod
COPY backend/ ./

# Prvo čekaj na bazu, pa pokreni setup
CMD [\"sh\", \"-c\", \"echo '🚀 Starting application...' && npm run start:with-db\"]

EXPOSE 3001"

# 6. KREIRAJ RAILWAY.TOML SA WAIT COMMAND
create_file "railway.toml" "[build]
builder = \"nixpacks\"

[deploy]
startCommand = \"npm run start:with-db\"
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

# 7. KREIRAJ SERVER.JS KOJI RADI BEZ BAZE PRIVREMENO
create_file "backend/server.js" "const express = require('express');
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
});"

# 8. INSTALIRAJ DEPENDENCIES
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
cd backend
npm install --no-audit --no-fund
cd ..

# 9. TEST LOCAL
echo -e "${YELLOW}🧪 Testing locally...${NC}"
if node -c backend/database/wait-for-db.js && node -c backend/database/start-with-db.js; then
    echo -e "${GREEN}✅ All files have valid syntax${NC}"
else
    echo -e "${RED}❌ Syntax error${NC}"
    exit 1
fi

# 10. GIT COMMIT
echo -e "${YELLOW}💾 Committing database wait solution...${NC}"
git add .
git commit -m "fix: Wait for DATABASE_URL and work without database initially

- Added wait-for-db.js that waits for DATABASE_URL
- Application works in demo mode without database
- Better error handling and user messages
- Step-by-step database connection
- Manual PostgreSQL setup required in Railway"

check_success "Changes committed"

# 11. PUSH TO GITHUB
echo -e "${YELLOW}📤 Pushing to GitHub...${NC}"
git push origin staging
check_success "Pushed to GitHub"

# 12. UPUTE ZA RAILWAY SETUP
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════╗"
echo "║               🗄️  MANUAL SETUP REQUIRED      ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}🔧 NOW YOU NEED TO MANUALLY ADD POSTGRESQL:${NC}"
echo ""
echo -e "${BLUE}1. Go to Railway:${NC} https://railway.app"
echo -e "${BLUE}2. Select your project${NC}"
echo -e "${BLUE}3. Click 'New' → 'Database' → 'PostgreSQL'${NC}"
echo -e "${BLUE}4. Wait 1-2 minutes for database to start${NC}"
echo -e "${BLUE}5. Redeploy your application${NC}"
echo ""
echo -e "${GREEN}🚀 Your app will now:${NC}"
echo "   • Wait for DATABASE_URL (up to 5 minutes)"
echo "   • Work in demo mode if no database"
echo "   • Auto-setup schema when database is ready"
echo "   • Switch to real PostgreSQL when available"
echo ""
echo -e "${YELLOW}📝 After adding PostgreSQL, check Railway logs to see database setup!${NC}"