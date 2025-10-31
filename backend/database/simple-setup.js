console.log('🧪 SIMPLE SETUP: Starting...');

// Prvo provjeri osnove
console.log('1. Checking basics...');
console.log('   NODE_ENV:', process.env.NODE_ENV || 'not set');
console.log('   DATABASE_URL:', process.env.DATABASE_URL ? 'SET' : 'NOT SET');

if (!process.env.DATABASE_URL) {
    console.log('❌ DATABASE_URL not set - cannot continue');
    process.exit(1);
}

// Pokušaj jednostavnu konekciju
const { Pool } = require('pg');

console.log('2. Creating simple connection...');
const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: true
});

pool.connect()
    .then(client => {
        console.log('✅ Connected to database!');
        return client.query('SELECT 1 as test')
            .then(result => {
                console.log('✅ Simple query works:', result.rows[0]);
                client.release();
                pool.end();
                console.log('🎉 SIMPLE SETUP: SUCCESS!');
                process.exit(0);
            });
    })
    .catch(error => {
        console.log('❌ Simple setup failed:', error.message);
        process.exit(1);
    });
