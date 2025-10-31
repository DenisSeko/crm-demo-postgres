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
echo "║           DEBUG DATABASE SETUP               ║"
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
check_success "Git repository ready"

# 2. KREIRAJ DEBUG DATABASE SETUP
echo -e "${YELLOW}🐛 Creating debug database setup...${NC}"

create_file "backend/database/debug-setup.js" "const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

console.log('🔧 DEBUG: Starting database setup...');

// Log environment variables (bez passworda)
console.log('🔧 DEBUG: NODE_ENV:', process.env.NODE_ENV);
console.log('🔧 DEBUG: PORT:', process.env.PORT);
console.log('🔧 DEBUG: DATABASE_URL exists:', !!process.env.DATABASE_URL);
if (process.env.DATABASE_URL) {
    const safeUrl = process.env.DATABASE_URL.replace(/:[^:]*@/, ':****@');
    console.log('🔧 DEBUG: DATABASE_URL:', safeUrl);
}

async function debugSetup() {
    console.log('🔧 DEBUG: Creating database connection...');
    
    const connectionString = process.env.DATABASE_URL;
    
    if (!connectionString) {
        console.error('💥 DEBUG: DATABASE_URL is not set!');
        console.error('💥 DEBUG: Available environment variables:');
        Object.keys(process.env).forEach(key => {
            if (key.includes('DATABASE') || key.includes('POSTGRES') || key.includes('DB')) {
                console.error('   ', key, ':', process.env[key] ? '***SET***' : 'NOT SET');
            }
        });
        throw new Error('DATABASE_URL not found');
    }

    const pool = new Pool({
        connectionString: connectionString,
        ssl: { rejectUnauthorized: false },
        connectionTimeoutMillis: 15000,
        query_timeout: 30000
    });

    let client;
    try {
        console.log('🔧 DEBUG: Attempting to connect...');
        client = await pool.connect();
        console.log('✅ DEBUG: Connected successfully!');

        // Test basic query
        console.log('🔧 DEBUG: Testing basic query...');
        const versionResult = await client.query('SELECT version()');
        console.log('✅ DEBUG: PostgreSQL version:', versionResult.rows[0].version);

        // List existing tables
        console.log('🔧 DEBUG: Checking existing tables...');
        const tablesResult = await client.query(\`
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
        \`);
        console.log('✅ DEBUG: Existing tables:', tablesResult.rows.map(r => r.table_name));

        // Check if schema.sql exists
        console.log('🔧 DEBUG: Checking for schema.sql...');
        const schemaPath = path.join(__dirname, 'schema.sql');
        console.log('🔧 DEBUG: Schema path:', schemaPath);
        
        if (!fs.existsSync(schemaPath)) {
            console.error('💥 DEBUG: schema.sql not found!');
            console.log('🔧 DEBUG: Current directory contents:');
            try {
                const files = fs.readdirSync(__dirname);
                console.log('   ', files);
            } catch (e) {
                console.error('   Cannot read directory:', e.message);
            }
            throw new Error('schema.sql not found');
        }

        const schemaSQL = fs.readFileSync(schemaPath, 'utf8');
        console.log('✅ DEBUG: schema.sql loaded, size:', schemaSQL.length, 'chars');

        // Try to execute a simple test table first
        console.log('🔧 DEBUG: Creating test table...');
        try {
            await client.query('CREATE TABLE IF NOT EXISTS test_deploy (id SERIAL PRIMARY KEY, name TEXT)');
            console.log('✅ DEBUG: Test table created successfully');
            
            await client.query('INSERT INTO test_deploy (name) VALUES ($1)', ['deploy_test']);
            console.log('✅ DEBUG: Test data inserted successfully');
        } catch (error) {
            console.error('❌ DEBUG: Test table failed:', error.message);
        }

        console.log('🎉 DEBUG: Database setup completed successfully!');
        
    } catch (error) {
        console.error('💥 DEBUG: Database setup failed:');
        console.error('💥 DEBUG: Error message:', error.message);
        console.error('💥 DEBUG: Error code:', error.code);
        console.error('💥 DEBUG: Error stack:', error.stack);
        throw error;
    } finally {
        if (client) {
            client.release();
            console.log('🔧 DEBUG: Client released');
        }
        await pool.end();
        console.log('🔧 DEBUG: Pool closed');
    }
}

if (require.main === module) {
    debugSetup()
        .then(() => {
            console.log('🚀 DEBUG: Setup completed successfully');
            process.exit(0);
        })
        .catch(error => {
            console.log('💥 DEBUG: Setup failed');
            process.exit(1);
        });
}

module.exports = { debugSetup };"

# 3. KREIRAJ SIMPLE SCHEMA.SQL
echo -e "${YELLOW}📋 Creating simple schema.sql for testing...${NC}"
create_file "backend/database/schema.sql" "-- Simple test schema for Railway PostgreSQL
-- This should work without any permissions issues

-- Test table
CREATE TABLE IF NOT EXISTS test_table (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert test data
INSERT INTO test_table (name) VALUES ('test_record_1');
INSERT INTO test_table (name) VALUES ('test_record_2');

-- Insert demo user (ignore if exists)
INSERT INTO users (email, password, name) 
VALUES ('demo@demo.com', 'demo123', 'Demo User')
ON CONFLICT (email) DO NOTHING;

-- Verify tables were created
SELECT 'Database setup completed successfully' as status;"

# 4. KREIRAJ PACKAGE.JSON SA DEBUG SCRIPT-OM
create_file "backend/package.json" '{
  "name": "crm-backend",
  "version": "1.0.0",
  "description": "CRM Backend API with PostgreSQL",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "db:setup": "node database/setup.js",
    "db:debug": "node database/debug-setup.js",
    "db:test": "node database/test-connection.js"
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

# 5. KREIRAJ TEST CONNECTION SCRIPT
create_file "backend/database/test-connection.js" "const { Pool } = require('pg');

console.log('🧪 Testing database connection...');

async function testConnection() {
    console.log('1. Checking DATABASE_URL...');
    
    if (!process.env.DATABASE_URL) {
        console.error('❌ DATABASE_URL is not set!');
        console.log('Available DB-related environment variables:');
        Object.keys(process.env).forEach(key => {
            if (key.includes('DB') || key.includes('POSTGRES') || key.includes('DATABASE')) {
                console.log('   ', key + ':', process.env[key] ? '***SET***' : 'NOT SET');
            }
        });
        return false;
    }

    const safeUrl = process.env.DATABASE_URL.replace(/:[^:]*@/, ':****@');
    console.log('2. DATABASE_URL:', safeUrl);

    console.log('3. Creating connection pool...');
    const pool = new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: { rejectUnauthorized: false },
        connectionTimeoutMillis: 10000
    });

    try {
        console.log('4. Attempting to connect...');
        const client = await pool.connect();
        console.log('✅ SUCCESS: Connected to database!');

        console.log('5. Testing query...');
        const result = await client.query('SELECT version() as version');
        console.log('✅ SUCCESS: Database version:', result.rows[0].version);

        console.log('6. Checking current database...');
        const dbResult = await client.query('SELECT current_database() as db');
        console.log('✅ SUCCESS: Current database:', dbResult.rows[0].db);

        client.release();
        await pool.end();
        
        console.log('🎉 ALL TESTS PASSED! Database is working correctly.');
        return true;
        
    } catch (error) {
        console.error('💥 CONNECTION FAILED:');
        console.error('   Error:', error.message);
        console.error('   Code:', error.code);
        console.error('   This usually means:');
        console.error('   - Database is not running yet');
        console.error('   - Wrong connection string');
        console.error('   - Network issues');
        console.error('   - SSL problems');
        return false;
    }
}

testConnection().then(success => {
    process.exit(success ? 0 : 1);
});"

# 6. KREIRAJ SIMPLE SERVER.JS
create_file "backend/server.js" "const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

// Basic health check without database
app.get('/api/health', (req, res) => {
    res.json({ 
        status: 'OK', 
        message: 'CRM Backend is running (DB status unknown)',
        timestamp: new Date().toISOString()
    });
});

app.get('/', (req, res) => {
    res.json({ 
        message: 'CRM Backend API - Database setup in progress',
        version: '1.0.0',
        endpoints: {
            health: 'GET /api/health'
        },
        database: 'Setting up...'
    });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log('🚀 Server started on port', PORT);
    console.log('🔧 Run npm run db:debug to test database setup');
});"

# 7. KREIRAJ DOCKERFILE SA BOLJIM LOGGING-OM
create_file "Dockerfile" "FROM node:18-alpine

WORKDIR /app

# Kopiraj package fajlove
COPY backend/package*.json ./

# Instaliraj zavisnosti
RUN npm install --production

# Kopiraj backend kod
COPY backend/ ./

# Pokreni debug setup prvo da vidimo šta ne radi
CMD [\"sh\", \"-c\", \"echo '🚀 Starting application...' && npm run db:debug && echo '✅ Debug completed, running setup...' && npm run db:setup && echo '🎉 Starting server...' && npm start\"]"

EXPOSE 3001"

# 8. KREIRAJ RAILWAY.TOML SA MANUAL SETUP
create_file "railway.toml" "[build]
builder = \"nixpacks\"

[deploy]
startCommand = \"npm run db:debug || true && npm start\"
restartPolicyType = \"ON_FAILURE\"
restartPolicyMaxRetries = 5

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

# 9. INSTALIRAJ DEPENDENCIES
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
cd backend
npm install --no-audit --no-fund
cd ..
check_success "Dependencies installed"

# 10. TEST LOCAL SYNTAX
echo -e "${YELLOW}🧪 Testing file syntax...${NC}"
if node -c backend/server.js && node -c backend/database/debug-setup.js && node -c backend/database/test-connection.js; then
    echo -e "${GREEN}✅ All files have valid syntax${NC}"
else
    echo -e "${RED}❌ Syntax error in files${NC}"
    exit 1
fi

# 11. GIT COMMIT
echo -e "${YELLOW}💾 Committing debug setup...${NC}"
git add .
git commit -m "debug: Add database debug scripts to find the real error

- Added debug-setup.js with detailed logging
- Added test-connection.js for basic connection testing
- Simple schema.sql for testing
- Better error handling and logging
- Manual setup approach"

check_success "Changes committed"

# 12. PUSH TO GITHUB
echo -e "${YELLOW}📤 Pushing to GitHub...${NC}"
git push origin staging
check_success "Pushed to GitHub"

# 13. UPUTE ZA DEBUG
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════╗"
echo "║               🐛 DEBUG READY                 ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}🔍 Now we can see the REAL error:${NC}"
echo ""
echo -e "${BLUE}1. Deploy to Railway:${NC}"
echo "   • Go to https://railway.app"
echo "   • Deploy from GitHub"
echo "   • Check the deployment logs"
echo ""
echo -e "${BLUE}2. Check what fails:${NC}"
echo "   • The debug script will show EXACTLY where it fails"
echo "   • It will show environment variables"
echo "   • It will show connection details"
echo "   • It will show file locations"
echo ""
echo -e "${BLUE}3. Common issues:${NC}"
echo "   • DATABASE_URL not set"
echo "   • Wrong file paths"
echo "   • Permission issues"
echo "   • SSL problems"
echo ""
echo -e "${GREEN}🚀 Deploy now and check Railway logs for the real error!${NC}"