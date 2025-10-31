console.log('🚀 STARTING DATABASE SETUP...');

// Prvo napravi basic check
try {
    console.log('1. Running basic environment check...');
    require('./basic-check.js');
} catch (error) {
    console.log('❌ Basic check failed:', error.message);
    process.exit(1);
}

// Sada pokušaj database setup
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

console.log('2. Checking DATABASE_URL...');
if (!process.env.DATABASE_URL) {
    console.error('💥 CRITICAL: DATABASE_URL is not set!');
    console.error('💥 This means Railway has not provided the database connection string.');
    console.error('💥 Possible reasons:');
    console.error('   - Database service is not linked to your project');
    console.error('   - Database is still starting up');
    console.error('   - Environment variables are not injected yet');
    process.exit(1);
}

console.log('3. DATABASE_URL is available, creating connection...');
const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 10000
});

async function setupDatabase() {
    let client;
    try {
        console.log('4. Attempting database connection...');
        client = await pool.connect();
        console.log('✅ SUCCESS: Connected to database!');

        console.log('5. Testing database...');
        const version = await client.query('SELECT version()');
        console.log('✅ Database version:', version.rows[0].version);

        console.log('6. Checking schema.sql...');
        const schemaPath = path.join(__dirname, 'schema.sql');
        if (!fs.existsSync(schemaPath)) {
            throw new Error('schema.sql not found at: ' + schemaPath);
        }

        const schemaSQL = fs.readFileSync(schemaPath, 'utf8');
        console.log('✅ schema.sql loaded');

        console.log('7. Executing schema...');
        const commands = schemaSQL.split(';').filter(cmd => cmd.trim().length > 0);
        
        for (let i = 0; i < commands.length; i++) {
            const command = commands[i] + ';';
            try {
                console.log('   Executing command', (i + 1), 'of', commands.length);
                await client.query(command);
            } catch (error) {
                if (error.message.includes('already exists')) {
                    console.log('   ⚠️  Command', (i + 1), 'skipped (already exists)');
                } else {
                    console.log('   ❌ Command failed:', error.message);
                    throw error;
                }
            }
        }

        console.log('🎉 DATABASE SETUP COMPLETED SUCCESSFULLY!');
        
    } catch (error) {
        console.error('💥 DATABASE SETUP FAILED:');
        console.error('   Error:', error.message);
        console.error('   This usually means:');
        console.error('   - Database is not ready yet');
        console.error('   - Connection string is wrong');
        console.error('   - Network/SSL issues');
        throw error;
    } finally {
        if (client) client.release();
        await pool.end();
    }
}

// Pokreni setup
setupDatabase()
    .then(() => {
        console.log('🚀 SETUP PROCESS COMPLETED');
        process.exit(0);
    })
    .catch(error => {
        console.log('💥 SETUP PROCESS FAILED');
        process.exit(1);
    });
