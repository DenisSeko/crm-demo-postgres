const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

async function setupDatabase() {
    console.log('🗄️  DATABASE SETUP: Starting...');
    
    if (!process.env.DATABASE_URL) {
        throw new Error('DATABASE_URL not available');
    }

    const pool = new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: { rejectUnauthorized: false }
    });

    try {
        const client = await pool.connect();
        console.log('✅ DATABASE SETUP: Connected to database');

        // Test
        await client.query('SELECT version()');
        console.log('✅ DATABASE SETUP: Database test passed');

        // Schema
        const schemaPath = path.join(__dirname, 'schema.sql');
        if (!fs.existsSync(schemaPath)) {
            throw new Error('schema.sql not found');
        }

        const schemaSQL = fs.readFileSync(schemaPath, 'utf8');
        const commands = schemaSQL.split(';').filter(cmd => cmd.trim().length > 0);
        
        console.log('📝 DATABASE SETUP: Executing', commands.length, 'commands');
        
        for (let i = 0; i < commands.length; i++) {
            try {
                await client.query(commands[i] + ';');
            } catch (error) {
                if (!error.message.includes('already exists')) {
                    throw error;
                }
            }
        }

        console.log('🎉 DATABASE SETUP: Completed successfully!');
        client.release();
        
    } catch (error) {
        console.log('❌ DATABASE SETUP: Failed:', error.message);
        throw error;
    } finally {
        await pool.end();
    }
}

module.exports = { setupDatabase };

// Auto-run if called directly
if (require.main === module) {
    setupDatabase().catch(console.error);
}
