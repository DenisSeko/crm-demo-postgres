const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

async function initializeDatabase() {
    console.log('🗄️  Initializing PostgreSQL database from schema.sql...');
    
    const pool = new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
    });

    try {
        // POKUŠAJ RAZLIČITE PUTANJE DO SCHEMA.SQL
        const possiblePaths = [
            path.join(__dirname, 'schema.sql'),                    // /app/database/schema.sql
            path.join(__dirname, '..', 'schema.sql'),              // /app/schema.sql  
            path.join(__dirname, '..', '..', 'database', 'schema.sql'), // /database/schema.sql
            '/app/database/schema.sql',                            // Apsolutna putanja u Dockeru
            '/app/schema.sql',                                     // Apsolutna putanja u Dockeru
            './database/schema.sql',                               // Relativna putanja
            './schema.sql'                                         // Relativna putanja
        ];
        
        let schemaPath = null;
        let schemaSQL = null;
        
        // Pronađi schema.sql na bilo kojoj od mogućih putanja
        for (const possiblePath of possiblePaths) {
            try {
                console.log('🔍 Looking for schema.sql at:', possiblePath);
                if (fs.existsSync(possiblePath)) {
                    schemaPath = possiblePath;
                    schemaSQL = fs.readFileSync(possiblePath, 'utf8');
                    console.log('✅ Found schema.sql at:', schemaPath);
                    break;
                }
            } catch (error) {
                // Nastavi sa sljedećom putanjom
                console.log('❌ Not found at:', possiblePath);
            }
        }
        
        if (!schemaSQL) {
            console.log('❌ schema.sql not found at any known location');
            console.log('📁 Current working directory:', process.cwd());
            console.log('📁 Directory contents:');
            try {
                const files = fs.readdirSync('.');
                console.log('Root:', files);
                
                if (fs.existsSync('./database')) {
                    const dbFiles = fs.readdirSync('./database');
                    console.log('Database folder:', dbFiles);
                }
                
                if (fs.existsSync('./app')) {
                    const appFiles = fs.readdirSync('./app');
                    console.log('App folder:', appFiles);
                }
            } catch (error) {
                console.log('⚠️  Could not read directory structure');
            }
            throw new Error('schema.sql not found');
        }
        
        console.log('📖 Running schema.sql from:', schemaPath);
        
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
        const userCheck = await pool.query('SELECT * FROM users WHERE email = ', ['demo@demo.com']);
        
        if (userCheck.rows.length === 0) {
            // Dodaj demo usera
            await pool.query(
                'INSERT INTO users (email, password, name) VALUES (, , )',
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
if (require.main === module) {
    initializeDatabase().catch(console.error);
}

module.exports = { initializeDatabase };
