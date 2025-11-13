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
    
    # Postavi DATABASE_URL za lokalni development
    export DATABASE_URL="postgresql://crm_user:crm_password@localhost:5433/crm_demo"
    echo "🔧 DATABASE_URL: postgresql://crm_user:****@localhost:5433/crm_demo"
    
    # Sačekaj malo da se baza potpuno pokrene
    sleep 3
    
    # Prvo provjeri je li baza dostupna
    echo "🔍 Provjeravam dostupnost baze..."
    if node -e "
        import pkg from 'pg';
        const { Pool } = pkg;
        const pool = new Pool({
            connectionString: process.env.DATABASE_URL,
            ssl: false
        });
        
        pool.query('SELECT 1')
            .then(() => {
                console.log('✅ Baza je dostupna');
                process.exit(0);
            })
            .catch(err => {
                console.error('❌ Baza nije dostupna:', err.message);
                process.exit(1);
            });
    "; then
        echo "✅ Baza je dostupna, pokrećem inicijalizaciju..."
        
        # Pokreni inicijalizaciju
        if node database/init.js; then
            echo "✅ Baza inicijalizirana!"
        else
            echo "❌ Greška pri inicijalizaciji baze"
            # Probaj s jednostavnijom inicijalizacijom
            echo "🔄 Pokušavam s jednostavnijom inicijalizacijom..."
            simple_init
        fi
    else
        echo "❌ Baza nije dostupna, preskačem inicijalizaciju"
    fi
    cd ..
}

# Jednostavna inicijalizacija ako glavna faila
simple_init() {
    echo "🔄 Pokrećem jednostavnu inicijalizaciju baze..."
    node -e "
        import pkg from 'pg';
        const { Pool } = pkg;
        
        const pool = new Pool({
            connectionString: process.env.DATABASE_URL,
            ssl: false
        });
        
        async function simpleInit() {
            const client = await pool.connect();
            try {
                // Kreiraj tablice sa SERIAL umjesto UUID
                await client.query(\`
                    CREATE TABLE IF NOT EXISTS users (
                        id SERIAL PRIMARY KEY,
                        email VARCHAR(255) UNIQUE NOT NULL,
                        password VARCHAR(255) NOT NULL,
                        name VARCHAR(255) NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                \`);
                
                await client.query(\`
                    CREATE TABLE IF NOT EXISTS clients (
                        id SERIAL PRIMARY KEY,
                        name VARCHAR(255) NOT NULL,
                        email VARCHAR(255) NOT NULL,
                        company VARCHAR(255),
                        owner_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                \`);
                
                await client.query(\`
                    CREATE TABLE IF NOT EXISTS notes (
                        id SERIAL PRIMARY KEY,
                        content TEXT NOT NULL,
                        client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                \`);
                
                console.log('✅ Tablice kreirane');
                
                // Dodaj demo korisnika
                const result = await client.query(
                    'INSERT INTO users (email, password, name) VALUES (\$1, \$2, \$3) ON CONFLICT (email) DO NOTHING RETURNING id',
                    ['demo@demo.com', 'demo123', 'Demo User']
                );
                
                if (result.rows.length > 0) {
                    console.log('✅ Demo korisnik dodan: demo@demo.com / demo123');
                } else {
                    console.log('ℹ️  Demo korisnik već postoji');
                }
                
            } catch (error) {
                console.error('❌ Greška:', error.message);
            } finally {
                client.release();
                await pool.end();
            }
        }
        
        simpleInit();
    "
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
    
    # Postavi DATABASE_URL za backend
    export DATABASE_URL="postgresql://crm_user:crm_password@localhost:5433/crm_demo"
    
    # Pokreni backend
    cd backend
    npm run dev &
    BACKEND_PID=$!
    echo "✅ Backend pokrenut (PID: $BACKEND_PID)"
    cd ..
    
    # Sačekaj da backend pokrene
    echo "⏳ Čekam backend (5 sekundi)..."
    sleep 5
    
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
echo "🔧 Backend:  http://localhost:8888"
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