const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
const { waitForDatabase } = require('./wait-for-db');
require('dotenv').config();

async function initializeDatabase() {
    console.log('🗄️  Starting PostgreSQL database initialization...');
    
    // Prvo pričekaj da baza bude spremna
    const dbReady = await waitForDatabase();
    if (!dbReady) {
        throw new Error('Database is not ready for initialization');
    }
    
    console.log('✅ Database is ready, proceeding with schema setup...');
    
    const pool = new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
    });

    try {
        // Pronađi schema.sql
        const schemaPath = path.join(__dirname, 'schema.sql');
        console.log('🔍 Looking for schema.sql at:', schemaPath);
        
        if (!fs.existsSync(schemaPath)) {
            throw new Error('schema.sql not found at: ' + schemaPath);
        }
        
        const schemaSQL = fs.readFileSync(schemaPath, 'utf8');
        console.log('✅ Found schema.sql, running database setup...');
        
        // Podijeli SQL komande i pokreni ih jednu po jednu
        const sqlCommands = schemaSQL
            .split(';')
            .map(cmd => cmd.trim())
            .filter(cmd => cmd.length > 0);
        
        console.log('📝 Found', sqlCommands.length, 'SQL commands to execute');
        
        for (let i = 0; i < sqlCommands.length; i++) {
            const command = sqlCommands[i] + ';';
            try {
                console.log('🔄 Executing command', (i + 1), 'of', sqlCommands.length);
                await pool.query(command);
                console.log('✅ Command', (i + 1), 'executed successfully');
            } catch (error) {
                // Ako je greška "relation already exists", ignoriši je
                if (error.message.includes('already exists')) {
                    console.log('⚠️  Table already exists, continuing...');
                } else {
                    throw error;
                }
            }
        }
        
        console.log('✅ All SQL commands executed successfully');
        
        // Dodaj demo podatke
        await seedDemoData(pool);
        
        console.log('🎉 Database initialization completed successfully!');
        
    } catch (error) {
        console.error('❌ Database initialization error:', error.message);
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
        console.log('⚠️  Could not seed demo data:', error.message);
    }
}

// Pokreni inicijalizaciju ako je skripta pozvana direktno
if (require.main === module) {
    initializeDatabase()
        .then(() => {
            console.log('🚀 Database initialization process completed');
            process.exit(0);
        })
        .catch(error => {
            console.error('💥 Database initialization failed:', error);
            process.exit(1);
        });
}

module.exports = { initializeDatabase };
