const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

async function setupDatabase() {
    console.log('🚀 Starting database setup...');
    
    // Koristi DATABASE_URL od Railway-a
    const connectionString = process.env.DATABASE_URL;
    
    if (!connectionString) {
        throw new Error('DATABASE_URL environment variable is not set');
    }
    
    console.log('🔌 Using DATABASE_URL:', connectionString.replace(/:[^:]*@/, ':****@'));
    
    const pool = new Pool({
        connectionString: connectionString,
        ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
        connectionTimeoutMillis: 10000,
        query_timeout: 30000
    });

    let client;
    try {
        // Pokušaj spojiti se na bazu
        console.log('⏳ Connecting to PostgreSQL...');
        client = await pool.connect();
        console.log('✅ Connected to PostgreSQL successfully!');

        // Testiraj connection
        console.log('🧪 Testing database connection...');
        const result = await client.query('SELECT version()');
        console.log('✅ PostgreSQL Version:', result.rows[0].version);

        // Pročitaj schema.sql
        console.log('📖 Reading schema.sql...');
        const schemaPath = path.join(__dirname, 'schema.sql');
        
        if (!fs.existsSync(schemaPath)) {
            throw new Error('schema.sql not found at: ' + schemaPath);
        }
        
        const schemaSQL = fs.readFileSync(schemaPath, 'utf8');
        console.log('✅ schema.sql loaded, size:', schemaSQL.length, 'characters');

        // Pokreni SQL komande jednu po jednu
        console.log('🔄 Executing schema...');
        const commands = schemaSQL
            .split(';')
            .map(cmd => cmd.trim())
            .filter(cmd => cmd.length > 0 && !cmd.startsWith('--'));

        console.log('📝 Found', commands.length, 'SQL commands to execute');

        for (let i = 0; i < commands.length; i++) {
            const command = commands[i] + ';';
            try {
                console.log('   Executing command', (i + 1), 'of', commands.length);
                await client.query(command);
                console.log('   ✅ Command', (i + 1), 'executed successfully');
            } catch (error) {
                // Ako je "već postoji" greška, ignoriši je
                if (error.message.includes('already exists') || 
                    error.message.includes('duplicate key') ||
                    error.message.includes('exists')) {
                    console.log('   ⚠️  Command', (i + 1), 'skipped (already exists):', error.message);
                } else {
                    console.log('   ❌ Command', (i + 1), 'failed:', error.message);
                    throw error;
                }
            }
        }

        console.log('🎉 Database setup completed successfully!');

        // Provjeri tabele
        console.log('📊 Checking created tables...');
        const tablesResult = await client.query(`
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
        `);
        
        console.log('✅ Available tables:', tablesResult.rows.map(row => row.table_name).join(', '));

    } catch (error) {
        console.error('💥 Database setup failed:', error.message);
        throw error;
    } finally {
        if (client) {
            client.release();
        }
        await pool.end();
    }
}

// Pokreni setup ako je skripta pozvana direktno
if (require.main === module) {
    setupDatabase()
        .then(() => {
            console.log('🚀 Database setup process completed');
            process.exit(0);
        })
        .catch(error => {
            console.error('💥 Database setup process failed');
            process.exit(1);
        });
}

module.exports = { setupDatabase };
