#!/bin/bash

echo "🚀 CRM DEMO - PostgreSQL Version (Port 5433)"

# Provjera je li Docker pokrenut
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker nije pokrenut. Pokreni Docker prvo."
    exit 1
fi

# Funkcija za pokretanje PostgreSQL
start_postgres() {
    echo "🗄️  Pokrećem PostgreSQL na portu 5433..."
    
    # Zaustavi postojeći PostgreSQL ako radi
    docker-compose down 2>/dev/null || true
    
    # Pokreni novi
    docker-compose up -d postgres
    
    POSTGRES_READY_TIMEOUT=30
    echo "⏳ Čekam PostgreSQL na portu 5433 (timeout: $((POSTGRES_READY_TIMEOUT*2)) sekundi)..."
    for ((i=1; i<=POSTGRES_READY_TIMEOUT; i++)); do
        if docker-compose exec -T postgres pg_isready -U crm_user -d crm_demo > /dev/null 2>&1; then
            echo "✅ PostgreSQL spreman na portu 5433!"
            return 0
        fi
        echo "⏳ Još čekam PostgreSQL... ($i/$POSTGRES_READY_TIMEOUT)"
        sleep 2
    done
    echo "❌ PostgreSQL nije responsive nakon $((POSTGRES_READY_TIMEOUT*2)) sekundi"
    return 1
}

# Funkcija za inicijalizaciju baze
init_database() {
    echo "🔄 Inicijaliziram bazu..."
    cd backend
    if node database/init.js; then
        echo "✅ Baza inicijalizirana!"
    else
        echo "❌ Greška pri inicijalizaciji baze"
        exit 1
    fi
    cd ..
}

# Funkcija za instalaciju dependencies
install_deps() {
    echo "📦 Instaliram dependencies..."
    
    cd backend
    if [ ! -d "node_modules" ]; then
        echo "Instaliram backend dependencies..."
        npm install
    fi
    cd ..
    
    cd frontend
    if [ ! -d "node_modules" ]; then
        echo "Instaliram frontend dependencies..."
        npm install
    fi
    cd ..
}

# Funkcija za pokretanje servisa
start_services() {
    echo "🔧 Pokrećem servise..."
    
    # Zaustavi postojeće procese
    pkill -f "node.*server.js" 2>/dev/null || true
    pkill -f "vite" 2>/dev/null || true
    
    # Pokreni backend
    cd backend
    npm run dev &
    BACKEND_PID=$!
    echo "✅ Backend pokrenut (PID: $BACKEND_PID)"
    cd ..
    
    # Sačekaj da backend pokrene
    echo "⏳ Čekam backend..."
    sleep 3
    
    # Pokreni frontend
    cd frontend
    npm run dev &
    FRONTEND_PID=$!
    echo "✅ Frontend pokrenut (PID: $FRONTEND_PID)"
    cd ..
}

# Glavni dio
cd "$(dirname "$0")"

echo "=================================================="
echo "🔄 Pokrećem CRM Demo..."
echo "=================================================="

start_postgres
install_deps
init_database
start_services

echo " "
echo "=================================================="
echo "🎉 CRM DEMO S POSTGRESQL JE POKRENUT!"
echo "=================================================="
echo "🌐 Frontend: http://localhost:5173"
echo "🔧 Backend:  http://localhost:3001"
echo "🗄️  PostgreSQL: localhost:5433"
echo " "
echo "🔐 Demo login: demo@demo.com / demo123"
echo " "
echo "📝 Funkcionalnosti:"
echo "   ✅ Moderni Vue 3 frontend"
echo "   ✅ Node.js backend API"
echo "   ✅ PostgreSQL baza podataka (port 5433)"
echo "   ✅ Upravljanje klijentima (CRUD)"
echo "   ✅ Bilješke za klijente"
echo "   ✅ Statistika"
echo "   ✅ Loader između stranica"
echo " "
echo "🛑 Zaustavi sa: Ctrl+C"
echo "=================================================="

# Cleanup funkcija
cleanup() {
    echo " "
    echo "🛑 Zaustavljam servise..."
    kill $BACKEND_PID $FRONTEND_PID 2>/dev/null || true
    docker-compose down
    echo "✅ Zaustavljeno!"
    exit 0
}

trap cleanup INT

# Beskonačna petlja
while true; do
    sleep 60
done
