#!/bin/bash
echo "🛑 Zaustavljam CRM Demo..."
docker-compose down 2>/dev/null
pkill -f "node.*server.js" 2>/dev/null
pkill -f "vite" 2>/dev/null
echo "✅ Sve zaustavljeno!"
