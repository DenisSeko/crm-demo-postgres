// server.js
import express from 'express';
import cors from 'cors';
import pkg from 'pg';
const { Pool } = pkg;
import fs from 'fs';
import path from 'path';

const app = express();
const PORT = process.env.PORT || 3001;

// ⭐⭐⭐ DATABASE INIT - JEDNOSTAVNO I EFIKASNO ⭐⭐⭐
async function initializeDatabase() {
    console.log('🔧 Initializing database...');
    
    const pool = new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: { rejectUnauthorized: false }
    });

    try {
        const client = await pool.connect();
        
        // Prvo provjeri postoje li tabele
        const result = await client.query(`
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
        `);
        
        if (result.rows.length === 0) {
            console.log('📦 No tables found, importing schema...');
            
            // Čitaj schema.sql
            const schemaPath = path.join(process.cwd(), 'database', 'schema.sql');
            if (fs.existsSync(schemaPath)) {
                const schemaSQL = fs.readFileSync(schemaPath, 'utf8');
                console.log('📄 Importing schema.sql...');
                await client.query(schemaSQL);
                console.log('✅ Schema imported successfully!');
            } else {
                console.log('❌ schema.sql not found at:', schemaPath);
                // Kreiraj basic schema
                await createBasicSchema(client);
            }
        } else {
            console.log(`✅ Database already has ${result.rows.length} tables`);
        }
        
        client.release();
    } catch (error) {
        console.error('❌ Database init error:', error.message);
    } finally {
        await pool.end();
    }
}

async function createBasicSchema(client) {
    console.log('🔨 Creating basic schema...');
    
    const basicSQL = `
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            email VARCHAR(255) UNIQUE NOT NULL,
            password VARCHAR(255) NOT NULL,
            name VARCHAR(255),
            created_at TIMESTAMP DEFAULT NOW()
        );

        CREATE TABLE IF NOT EXISTS clients (
            id SERIAL PRIMARY KEY,
            name VARCHAR(255) NOT NULL,
            email VARCHAR(255),
            company VARCHAR(255),
            owner_id INTEGER REFERENCES users(id),
            created_at TIMESTAMP DEFAULT NOW()
        );

        CREATE TABLE IF NOT EXISTS notes (
            id SERIAL PRIMARY KEY,
            content TEXT NOT NULL,
            client_id INTEGER REFERENCES clients(id) ON DELETE CASCADE,
            created_at TIMESTAMP DEFAULT NOW()
        );

        INSERT INTO users (email, password, name) 
        VALUES ('demo@demo.com', 'demo123', 'Demo User')
        ON CONFLICT (email) DO NOTHING;
    `;
    
    await client.query(basicSQL);
    console.log('✅ Basic schema created with demo user');
}

// Pokreni database init
initializeDatabase();

// ⭐⭐⭐ KRAJ DATABASE INIT ⭐⭐⭐

// Ostali kod ide ovdje...
app.use(cors());
app.use(express.json());

app.get('/', (req, res) => {
    res.json({ message: 'CRM API is running!' });
});

// ... tvoje rute ...

app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
});