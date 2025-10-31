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
echo "║           FIX SYNTAX ERRORS                  ║"
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

# 2. KREIRAJ BASIC CHECK SCRIPT
echo -e "${YELLOW}🔧 Creating basic environment check...${NC}"

create_file "backend/database/basic-check.js" "console.log('🔍 BASIC CHECK: Starting environment check...');

// Check Node.js version
console.log('🔍 Node.js version:', process.version);

// Check if we're in production
console.log('🔍 NODE_ENV:', process.env.NODE_ENV || 'not set');

// Check critical environment variables
console.log('🔍 PORT:', process.env.PORT || 'not set');

// Check for DATABASE_URL - this is the main issue!
console.log('🔍 DATABASE_URL exists:', !!process.env.DATABASE_URL);
if (process.env.DATABASE_URL) {
    const safeUrl = process.env.DATABASE_URL.replace(/:[^:]*@/, ':****@');
    console.log('🔍 DATABASE_URL (safe):', safeUrl);
    
    // Test if it's a valid PostgreSQL URL
    if (process.env.DATABASE_URL.includes('postgres://') || process.env.DATABASE_URL.includes('postgresql://')) {
        console.log('✅ DATABASE_URL looks like a valid PostgreSQL URL');
    } else {
        console.log('❌ DATABASE_URL does not look like a PostgreSQL URL');
    }
} else {
    console.log('❌ DATABASE_URL is NOT SET!');
    console.log('🔍 All environment variables:');
    Object.keys(process.env).forEach(key => {
        console.log('   ', key, ':', process.env[key] ? '***SET***' : 'NOT SET');
    });
}

// Check if required files exist
const fs = require('fs');
const path = require('path');

console.log('🔍 Checking required files...');
const requiredFiles = [
    'package.json',
    'server.js', 
    'database/setup.js',
    'database/schema.sql'
];

requiredFiles.forEach(file => {
    const filePath = path.join(__dirname, '..', file);
    const exists = fs.existsSync(filePath);
    console.log(exists ? '✅' : '❌', file, exists ? 'EXISTS' : 'MISSING');
    if (!exists && file === 'database/schema.sql') {
        console.log('   Current directory:', __dirname);
        console.log('   Files in database directory:');
        try {
            const files = fs.readdirSync(path.join(__dirname));
            files.forEach(f => console.log('     -', f));
        } catch (e) {
            console.log('   Cannot read database directory:', e.message);
        }
    }
});

console.log('🎉 BASIC CHECK: Environment check completed');
process.exit(0);"

# 3. KREIRAJ NOVI SETUP SA BOLJOM ERROR HANDLING
create_file "backend/database/setup.js" "console.log('🚀 STARTING DATABASE SETUP...');

// Prvo napravi basic check
try {
    console.log('1. Running basic environment check...');
    require('./basic-check.js');
} catch (error) {
    console.log('❌ Basic check failed:', error.message);
    process.exit(1);
}

// Sada pokušaj database setup
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

console.log('2. Checking DATABASE_URL...');
if (!process.env.DATABASE_URL) {
    console.error('💥 CRITICAL: DATABASE_URL is not set!');
    console.error('💥 This means Railway has not provided the database connection string.');
    console.error('💥 Possible reasons:');
    console.error('   - Database service is not linked to your project');
    console.error('   - Database is still starting up');
    console.error('   - Environment variables are not injected yet');
    process.exit(1);
}

console.log('3. DATABASE_URL is available, creating connection...');
const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 10000
});

async function setupDatabase() {
    let client;
    try {
        console.log('4. Attempting database connection...');
        client = await pool.connect();
        console.log('✅ SUCCESS: Connected to database!');

        console.log('5. Testing database...');
        const version = await client.query('SELECT version()');
        console.log('✅ Database version:', version.rows[0].version);

        console.log('6. Checking schema.sql...');
        const schemaPath = path.join(__dirname, 'schema.sql');
        if (!fs.existsSync(schemaPath)) {
            throw new Error('schema.sql not found at: ' + schemaPath);
        }

        const schemaSQL = fs.readFileSync(schemaPath, 'utf8');
        console.log('✅ schema.sql loaded');

        console.log('7. Executing schema...');
        const commands = schemaSQL.split(';').filter(cmd => cmd.trim().length > 0);
        
        for (let i = 0; i < commands.length; i++) {
            const command = commands[i] + ';';
            try {
                console.log('   Executing command', (i + 1), 'of', commands.length);
                await client.query(command);
            } catch (error) {
                if (error.message.includes('already exists')) {
                    console.log('   ⚠️  Command', (i + 1), 'skipped (already exists)');
                } else {
                    console.log('   ❌ Command failed:', error.message);
                    throw error;
                }
            }
        }

        console.log('🎉 DATABASE SETUP COMPLETED SUCCESSFULLY!');
        
    } catch (error) {
        console.error('💥 DATABASE SETUP FAILED:');
        console.error('   Error:', error.message);
        console.error('   This usually means:');
        console.error('   - Database is not ready yet');
        console.error('   - Connection string is wrong');
        console.error('   - Network/SSL issues');
        throw error;
    } finally {
        if (client) client.release();
        await pool.end();
    }
}

// Pokreni setup
setupDatabase()
    .then(() => {
        console.log('🚀 SETUP PROCESS COMPLETED');
        process.exit(0);
    })
    .catch(error => {
        console.log('💥 SETUP PROCESS FAILED');
        process.exit(1);
    });"

# 4. KREIRAJ SIMPLE SCHEMA.SQL
create_file "backend/database/schema.sql" "-- Simple CRM Schema for Railway PostgreSQL
-- This should work without any issues

CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS clients (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    company VARCHAR(255),
    owner_id INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS notes (
    id SERIAL PRIMARY KEY,
    content TEXT NOT NULL,
    client_id INTEGER REFERENCES clients(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert demo data (safe with ON CONFLICT)
INSERT INTO users (email, password, name) 
VALUES ('demo@demo.com', 'demo123', 'Demo User')
ON CONFLICT (email) DO NOTHING;

INSERT INTO clients (name, email, company, owner_id) 
VALUES 
    ('John Doe', 'john@example.com', 'ABC Company', 1),
    ('Jane Smith', 'jane@example.com', 'XYZ Corp', 1)
ON CONFLICT (email) DO NOTHING;

INSERT INTO notes (content, client_id) 
VALUES 
    ('First meeting completed', 1),
    ('Follow up scheduled', 1),
    ('Product demo requested', 2)
ON CONFLICT DO NOTHING;"

# 5. KREIRAJ PACKAGE.JSON SA BOLJIM SCRIPT-OVIMA
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
    "db:simple": "node database/simple-setup.js"
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

# 6. KREIRAJ SIMPLE SETUP BEZ COMPLEX ERROR HANDLING
create_file "backend/database/simple-setup.js" "console.log('🧪 SIMPLE SETUP: Starting...');

// Prvo provjeri osnove
console.log('1. Checking basics...');
console.log('   NODE_ENV:', process.env.NODE_ENV || 'not set');
console.log('   DATABASE_URL:', process.env.DATABASE_URL ? 'SET' : 'NOT SET');

if (!process.env.DATABASE_URL) {
    console.log('❌ DATABASE_URL not set - cannot continue');
    process.exit(1);
}

// Pokušaj jednostavnu konekciju
const { Pool } = require('pg');

console.log('2. Creating simple connection...');
const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: true
});

pool.connect()
    .then(client => {
        console.log('✅ Connected to database!');
        return client.query('SELECT 1 as test')
            .then(result => {
                console.log('✅ Simple query works:', result.rows[0]);
                client.release();
                pool.end();
                console.log('🎉 SIMPLE SETUP: SUCCESS!');
                process.exit(0);
            });
    })
    .catch(error => {
        console.log('❌ Simple setup failed:', error.message);
        process.exit(1);
    });"

# 7. KREIRAJ DOCKERFILE SA MANUAL APPROACH
create_file "Dockerfile" "FROM node:18-alpine

WORKDIR /app

# Kopiraj package fajlove
COPY backend/package*.json ./

# Instaliraj zavisnosti
RUN npm install --production

# Kopiraj backend kod
COPY backend/ ./

# Prvo testiraj osnove, pa pokušaj setup
CMD [\"sh\", \"-c\", \"echo '🚀 Starting application...' && npm run db:check && echo '---' && npm run db:simple && echo '---' && npm run db:setup && echo '🎉 Starting server...' && npm start\"]

EXPOSE 3001"

# 8. KREIRAJ RAILWAY.TOML SA MANUAL START
create_file "railway.toml" "[build]
builder = \"nixpacks\"

[deploy]
startCommand = \"npm run db:check && npm run db:simple && npm run db:setup && npm start\"
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

# 9. KREIRAJ SERVER.JS
create_file "backend/server.js" "const express = require('express');
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
});"

# 10. INSTALIRAJ DEPENDENCIES
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
cd backend
npm install --no-audit --no-fund
cd ..

# 11. TEST LOCAL
echo -e "${YELLOW}🧪 Testing locally...${NC}"
if node -c backend/database/basic-check.js && node -c backend/database/setup.js && node -c backend/database/simple-setup.js; then
    echo -e "${GREEN}✅ All files have valid syntax${NC}"
else
    echo -e "${RED}❌ Syntax error${NC}"
    exit 1
fi

# 12. GIT COMMIT
echo -e "${YELLOW}💾 Committing fixes...${NC}"
git add .
git commit -m "fix: Step-by-step database setup with better error reporting

- Added basic-check.js to test environment first
- Added simple-setup.js for basic connection test
- Better error messages and logging
- Step-by-step approach to find where it fails
- Manual start command for debugging"

check_success "Changes committed"

# 13. PUSH TO GITHUB
echo -e "${YELLOW}📤 Pushing to GitHub...${NC}"
git push origin staging
check_success "Pushed to GitHub"

# 14. UPUTE
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════╗"
echo "║               🔧 FIX DEPLOYED                ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}🚀 Now we'll see EXACTLY where it fails:${NC}"
echo ""
echo -e "${BLUE}Deployment will now run:${NC}"
echo "1. 🔍 db:check - Tests environment variables"
echo "2. 🧪 db:simple - Tests basic database connection" 
echo "3. 🚀 db:setup - Runs full schema setup"
echo "4. 🌐 npm start - Starts the server"
echo ""
echo -e "${GREEN}Check Railway logs after deploy to see which step fails!${NC}"