import { Pool } from 'pg';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function initializeDatabase() {
    console.log('🗄️  Initializing PostgreSQL database from schema.sql...');
    
    const pool = new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
    });

    try {
        // Pročitaj schema.sql fajl
        const schemaPath = path.join(__dirname, '..', '..', 'database', 'schema.sql');
        const schemaSQL = fs.readFileSync(schemaPath, 'utf8');
        
        console.log('📖 Running schema.sql...');
        
        // Pokreni SQL komande iz schema.sql
        await pool.query(schemaSQL);
        
        console.log('✅ Database initialized successfully from schema.sql');
        
        // Dodaj demo podatke ako su potrebni
        await seedDemoData(pool);
        
    } catch (error) {
        console.error('❌ Database initialization error:', error);
        throw error;
    } finally {
        await pool.end();
    }
}

async function seedDemoData(pool) {
    try {
        console.log('🌱 Seeding demo data...');
        
        // Provjeri da li već postoje demo podaci
        const userCheck = await pool.query('SELECT * FROM users WHERE email = $1', ['demo@demo.com']);
        
        if (userCheck.rows.length === 0) {
            // Dodaj demo usera
            await pool.query(
                'INSERT INTO users (email, password, name) VALUES ($1, $2, $3)',
                ['demo@demo.com', 'demo123', 'Demo User']
            );
            console.log('👤 Demo user created: demo@demo.com / demo123');
        } else {
            console.log('👤 Demo user already exists');
        }
        
    } catch (error) {
        console.log('⚠️  Could not seed demo data (table might not exist yet):', error.message);
    }
}

// Pokreni inicijalizaciju ako je skripta pozvana direktno
if (process.argv[1] === fileURLToPath(import.meta.url)) {
    initializeDatabase().catch(console.error);
}

export { initializeDatabase };
