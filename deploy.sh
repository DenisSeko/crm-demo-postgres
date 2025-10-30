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
    exit 1
fi
check_success "Git repository found"

# 2. PRIprema FRONTEND fajlova
echo -e "${YELLOW}🎨 Preparing frontend files...${NC}"

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

# frontend/vite.config.js
create_file "frontend/vite.config.js" 'import { defineConfig } from "vite"
import vue from "@vitejs/plugin-vue"

export default defineConfig({
  plugins: [vue()],
  base: "/",
  build: {
    outDir: "dist",
    emptyOutDir: true
  },
  server: {
    proxy: {
      "/api": {
        target: process.env.VITE_API_URL || "http://localhost:3001",
        changeOrigin: true
      }
    }
  }
})'

# frontend/.env.production
create_file "frontend/.env.production" 'VITE_API_URL=https://your-backend-app.up.railway.app'

# 3. PRIprema BACKEND fajlova
echo -e "${YELLOW}🔧 Preparing backend files...${NC}"

# backend/railway.json
create_file "backend/railway.json" '{
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "startCommand": "npm start",
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}'

# backend/Dockerfile
create_file "backend/Dockerfile" 'FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3001
CMD ["npm", "start"]'

# backend/.env.example
create_file "backend/.env.example" 'DB_HOST=localhost
DB_PORT=5432
DB_NAME=crm_production
DB_USER=postgres
DB_PASSWORD=your_secure_password
JWT_SECRET=your_very_secure_jwt_secret_here
NODE_ENV=production
FRONTEND_URL=https://your-crm-app.vercel.app
PORT=3001'

# 4. DATABASE SCHEMA
echo -e "${YELLOW}🗄️ Preparing database schema...${NC}"
mkdir -p database

create_file "database/schema.sql" 'CREATE TABLE IF NOT EXISTS users (
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
    client_id INTEGER REFERENCES clients(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (email, password, name) 
VALUES ('"'"'demo@demo.com'"'"', '"'"'demo123'"'"', '"'"'Demo User'"'"')
ON CONFLICT (email) DO NOTHING;'

# 5. TEST BUILD FRONTENDA
echo -e "${YELLOW}🧪 Testing frontend build...${NC}"
cd frontend
npm install > /dev/null 2>&1
npm run build > /dev/null 2>&1
cd ..
check_success "Frontend build test passed"

# 6. GIT COMMIT
echo -e "${YELLOW}💾 Committing changes to Git...${NC}"
git add . > /dev/null 2>&1
git commit -m "Prepare for Vercel + Railway deployment" > /dev/null 2>&1
check_success "Changes committed"

# 7. PUSH TO GITHUB
echo -e "${YELLOW}�� Pushing to GitHub...${NC}"
git push origin main > /dev/null 2>&1
check_success "Pushed to GitHub"

# 8. FINALNE UPUTE
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════╗"
echo "║               ✅ DEPLOYMENT READY            ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}📋 NEXT STEPS:${NC}"
echo ""
echo -e "${YELLOW}🌐 1. DEPLOY FRONTEND (Vercel):${NC}"
echo "   • Go to: ${BLUE}https://vercel.com${NC}"
echo "   • Click 'Import Project'"
echo "   • Select your GitHub repo"
echo "   • Set ROOT DIRECTORY to: ${GREEN}frontend${NC}"
echo "   • Framework: ${GREEN}Vite${NC}"
echo "   • Add Environment Variable:"
echo "     ${GREEN}VITE_API_URL = https://your-backend.up.railway.app${NC}"
echo ""
echo -e "${YELLOW}🔧 2. DEPLOY BACKEND (Railway):${NC}"
echo "   • Go to: ${BLUE}https://railway.app${NC}"
echo "   • Click 'New Project'"
echo "   • Select 'Deploy from GitHub repo'"
echo "   • Choose your repo"
echo "   • Add PostgreSQL database"
echo "   • Set these Environment Variables:"
echo "     ${GREEN}DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD${NC}"
echo "     ${GREEN}JWT_SECRET, NODE_ENV, FRONTEND_URL${NC}"
echo ""
echo -e "${YELLOW}🔄 3. UPDATE FRONTEND URL:${NC}"
echo "   • After Railway deployment, get your backend URL"
echo "   • Update Vercel Environment Variable:"
echo "     ${GREEN}VITE_API_URL = https://your-actual-backend.up.railway.app${NC}"
echo ""
echo -e "${YELLOW}🎉 4. YOUR APP WILL BE LIVE!${NC}"
echo "   • Frontend: ${GREEN}https://your-app.vercel.app${NC}"
echo "   • Backend: ${GREEN}https://your-backend.up.railway.app${NC}"
echo "   • Demo login: demo@demo.com / demo123"
echo ""
echo -e "${BLUE}💡 TIP: Run this script again if you need to update deployment files${NC}"
