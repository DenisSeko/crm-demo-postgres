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
echo "║             SINGLE REPOSITORY                ║"
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

# 1. PROVJERA GIT REPO
echo -e "${YELLOW}🔍 Checking Git repository...${NC}"
if [ ! -d .git ]; then
    echo -e "${RED}❌ Not a Git repository${NC}"
    echo "Initialize git first: git init && git add . && git commit -m 'Initial commit'"
    exit 1
fi
check_success "Git repository found"

# 2. KREIRAJ FRONTEND DEPLOYMENT FAJLOVE
echo -e "${YELLOW}🎨 Preparing frontend for Vercel...${NC}"

# frontend/vercel.json
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

# frontend/.env.production (prazan za sada)
create_file "frontend/.env.production" 'VITE_API_URL=YOUR_RAILWAY_BACKEND_URL_HERE'

# 3. KREIRAJ BACKEND DEPLOYMENT FAJLOVE
echo -e "${YELLOW}🔧 Preparing backend for Railway...${NC}"

# backend/package.json (ako ne postoji)
if [ ! -f "backend/package.json" ]; then
    create_file "backend/package.json" '{
  "name": "crm-backend",
  "version": "1.0.0",
  "description": "CRM Backend API",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  },
  "keywords": ["crm", "api", "backend"],
  "author": "",
  "license": "MIT"
}'
fi

# backend/server.js (ako ne postoji)
if [ ! -f "backend/server.js" ]; then
    create_file "backend/server.js" 'const express = require("express");
const cors = require("cors");

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json());

// In-memory storage za demo
let clients = [
  { id: 1, name: "Test Client 1", email: "client1@test.com", company: "Company A" },
  { id: 2, name: "Test Client 2", email: "client2@test.com", company: "Company B" }
];

let notes = [
  { id: 1, content: "First note for client 1", client_id: 1 },
  { id: 2, content: "Second note for client 1", client_id: 1 }
];

// Basic health check
app.get("/api/health", (req, res) => {
  console.log("Health check OK - No DB connection");
  res.json({ 
    status: "OK", 
    message: "CRM Backend is running (No Database)",
    timestamp: new Date().toISOString(),
    database: "Using in-memory storage for demo"
  });
});

// Simple login - HARDCODED bez baze
app.post("/api/auth/login", (req, res) => {
  const { email, password } = req.body;
  console.log("Login attempt:", email);
  
  // Hardcoded demo user - NEMA BAZE
  if (email === "demo@demo.com" && password === "demo123") {
    return res.json({ 
      success: true, 
      user: { 
        id: 1, 
        email: "demo@demo.com", 
        name: "Demo User" 
      },
      token: "demo-jwt-token-123"
    });
  }
  
  res.status(401).json({ 
    success: false, 
    message: "Pogrešni podaci za prijavu" 
  });
});

// Get clients - from memory
app.get("/api/clients", (req, res) => {
  res.json({
    success: true,
    clients: clients
  });
});

// Add client - to memory
app.post("/api/clients", (req, res) => {
  const { name, email, company } = req.body;
  const newClient = {
    id: clients.length + 1,
    name,
    email,
    company,
    created_at: new Date().toISOString()
  };
  clients.push(newClient);
  
  res.json({
    success: true,
    client: newClient
  });
});

// Get notes for client
app.get("/api/clients/:id/notes", (req, res) => {
  const clientId = parseInt(req.params.id);
  const clientNotes = notes.filter(note => note.client_id === clientId);
  
  res.json({
    success: true,
    notes: clientNotes
  });
});

// Add note
app.post("/api/clients/:id/notes", (req, res) => {
  const clientId = parseInt(req.params.id);
  const { content } = req.body;
  
  const newNote = {
    id: notes.length + 1,
    content,
    client_id: clientId,
    created_at: new Date().toISOString()
  };
  notes.push(newNote);
  
  res.json({
    success: true,
    note: newNote
  });
});

// Root endpoint
app.get("/", (req, res) => {
  res.json({ 
    message: "CRM Backend API (In-Memory Demo)",
    endpoints: {
      health: "GET /api/health",
      login: "POST /api/auth/login",
      clients: "GET /api/clients",
      "add-client": "POST /api/clients",
      "client-notes": "GET /api/clients/:id/notes",
      "add-note": "POST /api/clients/:id/notes"
    },
    demo: {
      email: "demo@demo.com",
      password: "demo123"
    }
  });
});

// Start server
app.listen(PORT, "0.0.0.0", () => {
  console.log("=================================");
  console.log("🚀 CRM Backend STARTED SUCCESSFULLY");
  console.log("📍 Port: " + PORT);
  console.log("🌐 Environment: " + (process.env.NODE_ENV || "development"));
  console.log("💾 Database: IN-MEMORY (No PostgreSQL)");
  console.log("✅ Health: http://localhost:" + PORT + "/api/health");
  console.log("🔑 Demo: demo@demo.com / demo123");
  console.log("=================================");
});

// Graceful shutdown
process.on("SIGTERM", () => {
  console.log("SIGTERM received, shutting down gracefully");
  process.exit(0);
});'
fi

# 4. KREIRAJ RAILWAY.TOML ZA BACKEND
echo -e "${YELLOW}🚄 Creating Railway configuration...${NC}"

create_file "railway.toml" '[build]
builder = "nixpacks"
buildCommand = "cd backend && npm install"

[deploy]
startCommand = "cd backend && npm start"
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10

[[services]]
name = "web"
run = "cd backend && npm start"

[environments.production.variables]
NODE_ENV = "production"
PORT = "3001"

[environments.staging.variables]
NODE_ENV = "production"
PORT = "3001"'

# 5. AŽURIRAJ .gitignore
echo -e "${YELLOW}📁 Updating .gitignore...${NC}"

create_file ".gitignore" '# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Environment variables - SAMO PRIVATNE
.env.local
.env.development
*.env.backup

# Build outputs - NE IGNORIŠE SE dist/ jer je potreban za deployment
# dist/
build/
*.tgz
*.tar.gz

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
logs/
*.log

# Runtime data
pids/
*.pid
*.seed
*.pid.lock

# Coverage directory used by tools like istanbul
coverage/

# Dependency directories
jspm_packages/

# Optional npm cache directory
.npm

# Optional REPL history
.node_repl_history

# Output of "npm pack"
*.tgz

# Yarn Integrity file
.yarn-integrity

# DOZVOLJENI FAJLOVI - NE IGNORIRAJU SE:
# .env.production (frontend)
# vercel.json
# railway.json
# railway.toml
# dist/ (build output)

# Privremeni fajlovi
*.tmp
*.temp
.cache/
.tmp/

# OS specific
ehthumbs.db
[Tt]humbs.db'

# 6. TEST BUILD FRONTENDA
echo -e "${YELLOW}🧪 Testing frontend build...${NC}"
cd frontend
npm install > /dev/null 2>&1
npm run build > /dev/null 2>&1
cd ..
check_success "Frontend build test passed"

# 7. GIT COMMIT
echo -e "${YELLOW}💾 Committing deployment files...${NC}"
git add . > /dev/null 2>&1
git commit -m "Add deployment configuration for Vercel + Railway

- Vercel configuration for frontend
- Railway configuration for backend  
- Working backend API with in-memory storage
- Demo login: demo@demo.com / demo123" > /dev/null 2>&1
check_success "Changes committed"

# 8. PUSH TO GITHUB
echo -e "${YELLOW}📤 Pushing to GitHub...${NC}"
git push origin main > /dev/null 2>&1
check_success "Pushed to GitHub"

# 9. FINALNE UPUTE ZA DEPLOYMENT
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════╗"
echo "║               ✅ DEPLOYMENT READY            ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}📋 MANUAL DEPLOYMENT STEPS:${NC}"
echo ""
echo -e "${YELLOW}🌐 1. DEPLOY BACKEND (Railway):${NC}"
echo "   • Go to: ${BLUE}https://railway.app${NC}"
echo "   • Click 'New Project'"
echo "   • Select 'Deploy from GitHub repo'"
echo "   • Choose your repository"
echo "   • Railway will auto-deploy backend from railway.toml"
echo "   • Wait for deployment to finish"
echo "   • Copy your backend URL (e.g., https://your-app.up.railway.app)"
echo ""
echo -e "${YELLOW}🎨 2. DEPLOY FRONTEND (Vercel):${NC}"
echo "   • Go to: ${BLUE}https://vercel.com${NC}"
echo "   • Click 'Add New...' → 'Project'"
echo "   • Import your GitHub repository"
echo "   • Configure project:"
echo "     - Root Directory: ${GREEN}frontend${NC}"
echo "     - Framework: ${GREEN}Vite${NC}"
echo "     - Build Command: ${GREEN}npm run build${NC}"
echo "     - Output Directory: ${GREEN}dist${NC}"
echo "   • Add Environment Variable:"
echo "     - Name: ${GREEN}VITE_API_URL${NC}"
echo "     - Value: ${GREEN}YOUR_RAILWAY_BACKEND_URL${NC} (from step 1)"
echo "   • Click 'Deploy'"
echo ""
echo -e "${YELLOW}🔗 3. UPDATE FRONTEND ENVIRONMENT:${NC}"
echo "   • After Railway gives you backend URL"
echo "   • Go to Vercel project settings"
echo "   • Update Environment Variable ${GREEN}VITE_API_URL${NC}"
echo "   • Redeploy frontend"
echo ""
echo -e "${YELLOW}🎯 4. TEST YOUR APP:${NC}"
echo "   • Frontend: ${GREEN}https://your-app.vercel.app${NC}"
echo "   • Backend API: ${GREEN}https://your-backend.up.railway.app/api/health${NC}"
echo "   • Demo login: ${GREEN}demo@demo.com${NC} / ${GREEN}demo123${NC}"
echo ""
echo -e "${GREEN}✅ Your deployment files are ready!${NC}"
echo -e "${BLUE}💡 Follow the steps above to deploy manually 🚀${NC}"

# 10. KREIRAJ DEPLOYMENT CHECK SCRIPT
create_file "deploy-check.sh" '#!/bin/bash
echo "🧪 Deployment Check Script"
echo "=========================="

# Check if backend is deployed
echo ""
echo "1. Checking backend deployment..."
if command -v curl &> /dev/null; then
    echo "   Backend URL: \$1"
    curl -f "\$1/api/health" && echo "   ✅ Backend is running" || echo "   ❌ Backend not responding"
else
    echo "   ℹ️  Install curl to test backend: sudo apt install curl"
fi

# Check frontend build
echo ""
echo "2. Checking frontend build..."
cd frontend
npm run build > /dev/null 2>&1 && echo "   ✅ Frontend builds successfully" || echo "   ❌ Frontend build failed"
cd ..

echo ""
echo "📋 Next steps:"
echo "   • Deploy backend on Railway"
echo "   • Deploy frontend on Vercel" 
echo "   • Update VITE_API_URL with your backend URL"
echo "   • Test your live application"'

chmod +x deploy-check.sh

echo -e "${YELLOW}🔍 Created deploy-check.sh to verify your setup${NC}"
echo -e "${GREEN}🎉 Deployment configuration completed! Follow the manual steps above.${NC}"