#!/bin/bash
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
echo "   • Test your live application"
