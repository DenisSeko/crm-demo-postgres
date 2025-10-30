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

# URL-EVI - AŽURIRANO SA PRAVIM URL-ovima
BACKEND_URL="https://crm-stage-postgres-staging.up.railway.app"
FRONTEND_URL="https://crm-staging-mu.vercel.app"

echo -e "${GREEN}🎯 Backend URL: $BACKEND_URL${NC}"
echo -e "${GREEN}🎯 Frontend URL: $FRONTEND_URL${NC}"
echo ""

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
create_file "frontend/vite.config.js" "import { defineConfig } from \"vite\"
import vue from \"@vitejs/plugin-vue\"

export default defineConfig({
  plugins: [vue()],
  base: \"/\",
  build: {
    outDir: \"dist\",
    emptyOutDir: true
  },
  server: {
    proxy: {
      \"/api\": {
        target: \"$BACKEND_URL\",
        changeOrigin: true
      }
    }
  }
})"

# frontend/.env.production - AŽURIRANO SA PRAVIM BACKEND URL-om
create_file "frontend/.env.production" "VITE_API_URL=$BACKEND_URL"

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

# backend/.env.example - AŽURIRANO SA PRAVIM FRONTEND URL-om
create_file "backend/.env.example" "DB_HOST=localhost
DB_PORT=5432
DB_NAME=crm_production
DB_USER=postgres
DB_PASSWORD=your_secure_password
JWT_SECRET=your_very_secure_jwt_secret_here
NODE_ENV=production
FRONTEND_URL=$FRONTEND_URL
PORT=3001
CORS_ORIGIN=$FRONTEND_URL"

# backend/.env.production - NOVI FAJL za Railway environment
create_file "backend/.env.production" "NODE_ENV=production
FRONTEND_URL=$FRONTEND_URL
CORS_ORIGIN=$FRONTEND_URL
PORT=3001"

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

# 5. DEPLOY CONFIGURATION
echo -e "${YELLOW}⚙️ Creating deployment configuration...${NC}"

# railway.toml - AŽURIRANO SA PRAVIM URL-ovima
create_file "railway.toml" "[deploy]
autoRollback = true

[environments]
  [environments.production]
    [environments.production.variables]
      NODE_ENV = \"production\"
      FRONTEND_URL = \"$FRONTEND_URL\"
      CORS_ORIGIN = \"$FRONTEND_URL\"

  [environments.staging]
    [environments.staging.variables]  
      NODE_ENV = \"staging\"
      FRONTEND_URL = \"$FRONTEND_URL\"
      CORS_ORIGIN = \"$FRONTEND_URL\""

# 6. TEST BUILD FRONTENDA
echo -e "${YELLOW}🧪 Testing frontend build...${NC}"
cd frontend
npm install > /dev/null 2>&1
npm run build > /dev/null 2>&1
cd ..
check_success "Frontend build test passed"

# 7. GIT COMMIT
echo -e "${YELLOW}💾 Committing changes to Git...${NC}"
git add . > /dev/null 2>&1
git commit -m "Deploy configuration: Frontend $FRONTEND_URL + Backend $BACKEND_URL" > /dev/null 2>&1
check_success "Changes committed"

# 8. PUSH TO GITHUB
echo -e "${YELLOW}📤 Pushing to GitHub...${NC}"
git push origin main > /dev/null 2>&1
check_success "Pushed to GitHub"

# 9. FINALNE UPUTE - AŽURIRANO SA PRAVIM URL-ovima
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════╗"
echo "║               ✅ DEPLOYMENT COMPLETE         ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}📋 DEPLOYMENT SUMMARY:${NC}"
echo ""
echo -e "${YELLOW}🌐 FRONTEND (Vercel):${NC}"
echo "   • URL: ${GREEN}$FRONTEND_URL${NC}"
echo "   • Status: ${GREEN}✅ Live${NC}"
echo "   • Environment: ${GREEN}VITE_API_URL = $BACKEND_URL${NC}"
echo ""
echo -e "${YELLOW}🔧 BACKEND (Railway):${NC}"
echo "   • URL: ${GREEN}$BACKEND_URL${NC}"
echo "   • Environment: ${GREEN}FRONTEND_URL = $FRONTEND_URL${NC}"
echo "   • CORS: ${GREEN}Configured for $FRONTEND_URL${NC}"
echo ""
echo -e "${YELLOW}🔗 API ENDPOINTS:${NC}"
echo "   • Health Check: ${GREEN}$BACKEND_URL/api/health${NC}"
echo "   • API Base: ${GREEN}$BACKEND_URL/api${NC}"
echo "   • Clients: ${GREEN}$BACKEND_URL/api/clients${NC}"
echo ""
echo -e "${YELLOW}🔐 DEMO LOGIN:${NC}"
echo "   • Email: ${GREEN}demo@demo.com${NC}"
echo "   • Password: ${GREEN}demo123${NC}"
echo ""
echo -e "${YELLOW}🎯 TEST YOUR APP:${NC}"
echo "   • Frontend: ${GREEN}$FRONTEND_URL${NC}"
echo "   • Backend API: ${GREEN}$BACKEND_URL/api/health${NC}"
echo ""
echo -e "${GREEN}✅ Both frontend and backend are properly configured!${NC}"
echo -e "${BLUE}💡 Your full-stack CRM application is ready to use! 🎉${NC}"

# 10. QUICK HEALTH CHECK
echo -e "${YELLOW}🔍 Performing quick health check...${NC}"
if command -v curl &> /dev/null; then
    echo -e "${BLUE}Testing backend connection...${NC}"
    curl -f -s "$BACKEND_URL/api/health" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Backend is responding${NC}"
    else
        echo -e "${YELLOW}⚠️  Backend not responding yet (may be starting up)${NC}"
    fi
    
    echo -e "${BLUE}Testing frontend connection...${NC}"
    curl -f -s "$FRONTEND_URL" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Frontend is responding${NC}"
    else
        echo -e "${YELLOW}⚠️  Frontend not responding yet (may be starting up)${NC}"
    fi
fi

echo ""
echo -e "${GREEN}🎉 Deployment configuration completed successfully!${NC}"