const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

console.log('🔄 BACKGROUND SETUP: Starting...');

async function setupDatabaseInBackground() {
    if (!process.env.DATABASE_URL) {
        console.log('⏳ BACKGROUND SETUP: Waiting for DATABASE_URL...');
        return new Promise((resolve) => {
            const checkInterval = setInterval(() => {
                if (process.env.DATABASE_URL) {
                    clearInterval(checkInterval);
                    console.log('✅ BACKGROUND SETUP: DATABASE_URL found, starting setup...');
                    performSetup().then(resolve);
                }
            }, 5000); // Check every 5 seconds
        });
    } else {
        console.log('✅ BACKGROUND SETUP: DATABASE_URL available, starting setup...');
        return performSetup();
    }
}

async function performSetup() {
    const pool = new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: { rejectUnauthorized: false }
    });

    try {
        const client = await pool.connect();
        console.log('✅ BACKGROUND SETUP: Connected to database');

        // Test connection
        await client.query('SELECT version()');
        console.log('✅ BACKGROUND SETUP: Database test successful');

        // Load and execute schema
        const schemaPath = path.join(__dirname, 'schema.sql');
        if (fs.existsSync(schemaPath)) {
            const schemaSQL = fs.readFileSync(schemaPath, 'utf8');
            const commands = schemaSQL.split(';').filter(cmd => cmd.trim().length > 0);
            
            console.log('📝 BACKGROUND SETUP: Executing', commands.length, 'SQL commands');
            
            for (let i = 0; i < commands.length; i++) {
                try {
                    await client.query(commands[i] + ';');
                } catch (error) {
                    if (!error.message.includes('already exists')) {
                        console.log('⚠️  BACKGROUND SETUP: Command', (i + 1), 'failed:', error.message);
                    }
                }
            }
            
            console.log('🎉 BACKGROUND SETUP: Database setup completed!');
        } else {
            console.log('❌ BACKGROUND SETUP: schema.sql not found');
        }

        client.release();
    } catch (error) {
        console.log('❌ BACKGROUND SETUP: Failed:', error.message);
    } finally {
        await pool.end();
    }
}

module.exports = { setupDatabaseInBackground };

// Auto-run if called directly
if (require.main === module) {
    setupDatabaseInBackground();
}
