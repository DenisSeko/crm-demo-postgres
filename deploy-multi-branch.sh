#!/bin/bash

# Boje za output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════╗"
echo "║           🚀 CRM DEPLOYMENT SCRIPT           ║"
echo "║         Development & Staging Branches       ║"
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

# 1. PROVJERA BRANCHA
echo -e "${YELLOW}🔍 Checking current branch...${NC}"
CURRENT_BRANCH=$(git branch --show-current)
echo -e "Current branch: ${CYAN}$CURRENT_BRANCH${NC}"

if [[ "$CURRENT_BRANCH" != "development" && "$CURRENT_BRANCH" != "staging" ]]; then
    echo -e "${RED}❌ You're not on development or staging branch${NC}"
    echo -e "${YELLOW}Available branches:${NC}"
    git branch
    echo ""
    read -p "Switch to which branch? (development/staging): " target_branch
    if [[ "$target_branch" == "development" || "$target_branch" == "staging" ]]; then
        git checkout $target_branch
        CURRENT_BRANCH=$target_branch
        check_success "Switched to $CURRENT_BRANCH branch"
    else
        echo -e "${RED}❌ Invalid branch selection${NC}"
        exit 1
    fi
fi

# 2. KREIRAJ FRONTEND FAJLOVE
echo -e "${YELLOW}🎨 Preparing frontend for Vercel...${NC}"

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

# Environment file za svaki branch
if [ "$CURRENT_BRANCH" = "staging" ]; then
    create_file "frontend/.env.production" 'VITE_API_URL=https://crm-staging-backend.up.railway.app
VITE_APP_ENV=staging'
else
    create_file "frontend/.env.production" 'VITE_API_URL=https://crm-development-backend.up.railway.app
VITE_APP_ENV=development'
fi

# 3. KREIRAJ BACKEND FAJLOVE
echo -e "${YELLOW}🔧 Preparing backend for Railway...${NC}"

if [ ! -f "backend/package.json" ]; then
    create_file "backend/package.json" '{
  "name": "crm-backend",
  "version": "1.0.0",
  "description": "CRM Backend API",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5"
  },
  "keywords": ["crm", "api", "backend"],
  "author": "",
  "license": "MIT"
}'
fi

# Server.js sa branch awareness
create_file "backend/server.js" "const express = require('express');
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
    branch: '$CURRENT_BRANCH',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString()
  });
});

// Login
app.post('/api/auth/login', (req, res) => {
  const { email, password } = req.body;
  console.log('Login attempt on $CURRENT_BRANCH:', email);
  
  if (email === 'demo@demo.com' && password === 'demo123') {
    return res.json({ 
      success: true, 
      user: { 
        id: 1, 
        email: 'demo@demo.com', 
        name: 'Demo User ($CURRENT_BRANCH)'
      },
      token: 'demo-token-$CURRENT_BRANCH-123'
    });
  }
  
  res.status(401).json({ success: false, message: 'Pogrešni podaci' });
});

// Clients API
app.get('/api/clients', (req, res) => {
  res.json({
    success: true,
    branch: '$CURRENT_BRANCH',
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
    branch: '$CURRENT_BRANCH',
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
  console.log('🌿 Branch: $CURRENT_BRANCH');
  console.log('🌐 Environment: ' + (process.env.NODE_ENV || 'development'));
  console.log('✅ Health: http://localhost:' + PORT + '/api/health');
});"

# 4. KREIRAJ RAILWAY.TOML SA MULTI-BRANCH SUPPORT
echo -e "${YELLOW}🚄 Creating Railway configuration for both branches...${NC}"

create_file "railway.toml" '[build]
builder = "nixpacks"
buildCommand = "cd backend && npm install"

[deploy]
startCommand = "cd backend && npm start"
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10

# 👇 DEPLOY BOTH BRANCHES TO DIFFERENT ENVIRONMENTS
branches = ["staging", "development"]

[[services]]
name = "web"
run = "cd backend && npm start"

# Staging Environment (staging branch)
[environments.staging]
branch = "staging"
variables = { 
    NODE_ENV = "staging", 
    PORT = "3001",
    APP_BRANCH = "staging"
}

# Development Environment (development branch)  
[environments.development]
branch = "development"
variables = { 
    NODE_ENV = "development", 
    PORT = "3001",
    APP_BRANCH = "development"
}'

# 5. KREIRAI SEPARATE VERCEL CONFIG PO BRANCHU
echo -e "${YELLOW}🌐 Creating Vercel configurations per branch...${NC}"

# Vercel config za staging
create_file "vercel-staging.json" '{
  "version": 2,
  "builds": [
    {
      "src": "frontend/package.json",
      "use": "@vercel/static-build",
      "config": {
        "distDir": "dist"
      }
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "/frontend/index.html"
    }
  ],
  "env": {
    "VITE_API_URL": "https://crm-staging-backend.up.railway.app",
    "VITE_APP_ENV": "staging"
  }
}'

# Vercel config za development
create_file "vercel-development.json" '{
  "version": 2,
  "builds": [
    {
      "src": "frontend/package.json",
      "use": "@vercel/static-build",
      "config": {
        "distDir": "dist"
      }
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "/frontend/index.html"
    }
  ],
  "env": {
    "VITE_API_URL": "https://crm-development-backend.up.railway.app", 
    "VITE_APP_ENV": "development"
  }
}'

# 6. GIT COMMIT & PUSH
echo -e "${YELLOW}💾 Committing deployment configuration...${NC}"
git add . > /dev/null 2>&1
git commit -m "Deploy config: Multi-branch setup (development & staging)

- Railway configured for both development and staging branches
- Branch-specific environment variables
- Current branch: $CURRENT_BRANCH
- Separate backend URLs for each environment" > /dev/null 2>&1
check_success "Changes committed"

echo -e "${YELLOW}📤 Pushing to GitHub ($CURRENT_BRANCH)...${NC}"
git push origin $CURRENT_BRANCH > /dev/null 2>&1
check_success "Pushed to GitHub"

# 7. FINALNE UPUTE
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════╗"
echo "║               ✅ DEPLOYMENT READY            ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}📋 DEPLOYMENT SETUP FOR BOTH BRANCHES:${NC}"
echo ""
echo -e "${CYAN}🚄 RAILWAY BACKEND DEPLOYMENT:${NC}"
echo "   • Staging branch: ${GREEN}https://crm-staging-backend.up.railway.app${NC}"
echo "   • Development branch: ${GREEN}https://crm-development-backend.up.railway.app${NC}"
echo "   • Railway will auto-deploy BOTH branches to separate environments"
echo ""
echo -e "${CYAN}🌐 VERCEL FRONTEND DEPLOYMENT:${NC}"
echo "   • Create TWO projects on Vercel:"
echo ""
echo -e "${YELLOW}   1. STAGING PROJECT:${NC}"
echo "      - Repository: your-repo"
echo "      - Branch: ${GREEN}staging${NC}"
echo "      - Root Directory: ${GREEN}frontend${NC}"
echo "      - Environment Variables:"
echo "        VITE_API_URL = ${GREEN}https://crm-staging-backend.up.railway.app${NC}"
echo "        VITE_APP_ENV = ${GREEN}staging${NC}"
echo ""
echo -e "${YELLOW}   2. DEVELOPMENT PROJECT:${NC}"
echo "      - Repository: your-repo" 
echo "      - Branch: ${GREEN}development${NC}"
echo "      - Root Directory: ${GREEN}frontend${NC}"
echo "      - Environment Variables:"
echo "        VITE_API_URL = ${GREEN}https://crm-development-backend.up.railway.app${NC}"
echo "        VITE_APP_ENV = ${GREEN}development${NC}"
echo ""
echo -e "${CYAN}🔧 BRANCH WORKFLOW:${NC}"
echo "   • ${GREEN}development${NC} → testing new features"
echo "   • ${GREEN}staging${NC} → pre-production testing"
echo "   • Push to ${GREEN}development${NC} → auto-deploys to development environment"
echo "   • Push to ${GREEN}staging${NC} → auto-deploys to staging environment"
echo ""
echo -e "${GREEN}✅ Multi-branch deployment configured!${NC}"
echo -e "${BLUE}💡 Push to either branch to trigger auto-deployment 🎉${NC}"

# 8. BRANCH MANAGEMENT SCRIPT
create_file "deploy-branch.sh" '#!/bin/bash
echo "🌿 Branch Deployment Manager"
echo "============================"

current_branch=$(git branch --show-current)
echo "Current branch: $current_branch"

case $current_branch in
    "staging")
        echo "🎯 Staging Environment"
        echo "Backend URL: https://crm-staging-backend.up.railway.app"
        echo "Use for: Pre-production testing"
        ;;
    "development") 
        echo "🔧 Development Environment"
        echo "Backend URL: https://crm-development-backend.up.railway.app"
        echo "Use for: Feature development & testing"
        ;;
    *)
        echo "❌ Unknown branch. Switch to staging or development."
        ;;
esac

echo ""
echo "🚀 Deployment Status:"
echo "   - Railway: Auto-deploys both branches"
echo "   - Vercel: Configure separate projects per branch"
echo ""
echo "📋 Commands:"
echo "   git checkout staging          # Switch to staging"
echo "   git checkout development      # Switch to development" 
echo "   git push origin staging       # Deploy staging"
echo "   git push origin development   # Deploy development"'

chmod +x deploy-branch.sh

echo -e "${YELLOW}🔧 Created deploy-branch.sh for branch management${NC}"
echo -e "${GREEN}🎉 Multi-branch deployment setup completed!${NC}"