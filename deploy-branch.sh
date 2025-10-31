#!/bin/bash

# Colors for output
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

# Success check function
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${RED}❌ $1${NC}"
        exit 1
    fi
}

# File creation function
create_file() {
    echo -e "${YELLOW}📝 Creating $1...${NC}"
    cat > $1 << CONTENT
$2
CONTENT
    check_success "Created $1"
}

# 1. CHECK CURRENT BRANCH
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

# 2. CREATE FRONTEND FILES
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

# Environment file for each branch
if [ "$CURRENT_BRANCH" = "staging" ]; then
    create_file "frontend/.env.production" 'VITE_API_URL=https://crm-staging-backend.up.railway.app
VITE_APP_ENV=staging'
else
    create_file "frontend/.env.production" 'VITE_API_URL=https://crm-development-backend.up.railway.app
VITE_APP_ENV=development'
fi

# 3. CREATE BACKEND PACKAGE.JSON IF NOT EXISTS
echo -e "${YELLOW}🔧 Checking backend configuration...${NC}"

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
else
    echo -e "${GREEN}✅ backend/package.json already exists - keeping as is${NC}"
fi

# 4. CREATE RAILWAY.TOML WITH MULTI-BRANCH SUPPORT
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
    NODE_ENV = "production", 
    PORT = "3001"
}

# Development Environment (development branch)  
[environments.development]
branch = "development"
variables = { 
    NODE_ENV = "development", 
    PORT = "3001"
}'

# 5. CREATE VERCEL CONFIGS PER BRANCH
echo -e "${YELLOW}🌐 Creating Vercel configurations per branch...${NC}"

# Vercel config for staging
create_file "vercel-staging.json" '{
  "version": 2,
  "buildCommand": "cd frontend && npm run build",
  "outputDirectory": "frontend/dist",
  "routes": [
    {
      "src": "/(.*)",
      "dest": "/frontend/dist/index.html"
    }
  ]
}'

# Vercel config for development
create_file "vercel-development.json" '{
  "version": 2,
  "buildCommand": "cd frontend && npm run build",
  "outputDirectory": "frontend/dist",
  "routes": [
    {
      "src": "/(.*)",
      "dest": "/frontend/dist/index.html"
    }
  ]
}'

# 6. CREATE DEPLOYMENT GUIDE
echo -e "${YELLOW}📋 Creating deployment guide...${NC}"

create_file "DEPLOYMENT_GUIDE.md" "# Deployment Guide

## Branch Strategy

### Development Branch
- **Use**: Feature development and testing
- **Backend URL**: https://crm-development-backend.up.railway.app
- **Frontend URL**: Your Vercel development domain
- **Auto-deploy**: Yes (on push to development branch)

### Staging Branch  
- **Use**: Pre-production testing
- **Backend URL**: https://crm-staging-backend.up.railway.app
- **Frontend URL**: Your Vercel staging domain
- **Auto-deploy**: Yes (on push to staging branch)

## Environment Variables

### Frontend (.env.production)
\`\`\`
VITE_API_URL=[BACKEND_URL]
VITE_APP_ENV=[development|staging]
\`\`\`

### Backend (Railway Environment)
- \`NODE_ENV\`: production (staging) / development (development)
- \`PORT\`: 3001

## Deployment Commands

\`\`\`bash
# Switch to development
git checkout development
git push origin development

# Switch to staging  
git checkout staging
git push origin staging

# Check deployment status
./deploy-branch.sh
\`\`\`

## Manual Setup Required

### Railway
1. Go to https://railway.app
2. Create new project
3. Connect GitHub repository
4. Railway will auto-detect branches from railway.toml

### Vercel  
1. Go to https://vercel.com
2. Create TWO projects:
   - **Staging Project**: Connect to staging branch
   - **Development Project**: Connect to development branch
3. For each project:
   - Root Directory: \`frontend\`
   - Framework: Vite
   - Build Command: \`npm run build\`
   - Output Directory: \`dist\`
4. Set environment variables:
   - \`VITE_API_URL\`: Backend URL for respective branch
   - \`VITE_APP_ENV\**: development or staging"

# 7. GIT COMMIT & PUSH
echo -e "${YELLOW}💾 Committing deployment configuration...${NC}"
git add . > /dev/null 2>&1
git commit -m "Configure multi-branch deployment (development & staging)

- Railway configured for both development and staging branches
- Branch-specific environment variables
- Current branch: $CURRENT_BRANCH
- Separate backend URLs for each environment
- Server.js configuration preserved as-is" > /dev/null 2>&1
check_success "Changes committed"

echo -e "${YELLOW}📤 Pushing to GitHub ($CURRENT_BRANCH)...${NC}"
git push origin $CURRENT_BRANCH > /dev/null 2>&1
check_success "Pushed to GitHub"

# 8. FINAL INSTRUCTIONS
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
echo "   • Your existing server.js configuration is preserved"
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
echo -e "${BLUE}💡 Your server.js configuration is preserved as-is 🎉${NC}"

# 9. BRANCH MANAGEMENT SCRIPT
create_file "deploy-branch.sh" '#!/bin/bash
echo "🌿 Branch Deployment Manager"
echo "============================"

current_branch=$(git branch --show-current)
echo "Current branch: $current_branch"

case $current_branch in
    "staging")
        echo "🎯 STAGING ENVIRONMENT"
        echo "Backend URL: https://crm-staging-backend.up.railway.app"
        echo "Use for: Pre-production testing"
        ;;
    "development") 
        echo "🔧 DEVELOPMENT ENVIRONMENT"
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
echo "📋 Quick Commands:"
echo "   git checkout staging          # Switch to staging"
echo "   git checkout development      # Switch to development" 
echo "   git push origin staging       # Deploy staging"
echo "   git push origin development   # Deploy development"'

chmod +x deploy-branch.sh

echo -e "${YELLOW}🔧 Created deploy-branch.sh for branch management${NC}"
echo -e "${GREEN}🎉 Multi-branch deployment setup completed!${NC}"
echo -e "${YELLOW}📖 See DEPLOYMENT_GUIDE.md for detailed instructions${NC}"