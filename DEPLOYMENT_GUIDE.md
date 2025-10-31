# Deployment Guide

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
```
VITE_API_URL=[BACKEND_URL]
VITE_APP_ENV=[development|staging]
```

### Backend (Railway Environment)
- `NODE_ENV`: production (staging) / development (development)
- `PORT`: 3001

## Deployment Commands

```bash
# Switch to development
git checkout development
git push origin development

# Switch to staging  
git checkout staging
git push origin staging

# Check deployment status
./deploy-branch.sh
```

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
   - Root Directory: `frontend`
   - Framework: Vite
   - Build Command: `npm run build`
   - Output Directory: `dist`
4. Set environment variables:
   - `VITE_API_URL`: Backend URL for respective branch
   - `VITE_APP_ENV\**: development or staging
