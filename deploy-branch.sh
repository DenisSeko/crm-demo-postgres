#!/bin/bash
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
echo "   git push origin development   # Deploy development"
