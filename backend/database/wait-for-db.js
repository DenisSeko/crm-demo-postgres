const { Pool } = require('pg');
require('dotenv').config();

async function waitForDatabase() {
    console.log('⏳ Waiting for PostgreSQL database to be ready...');
    
    const pool = new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
        // Kratki timeout za brže failanje
        connectionTimeoutMillis: 5000,
        query_timeout: 5000
    });

    let attempts = 0;
    const maxAttempts = 30; // 30 pokušaja = 2.5 minuta
    
    while (attempts < maxAttempts) {
        try {
            attempts++;
            console.log('🔌 Attempting database connection...', 'Attempt', attempts, 'of', maxAttempts);
            
            // Pokušaj spojiti se na bazu
            const client = await pool.connect();
            console.log('✅ Database connection successful!');
            
            // Testiraj connection
            await client.query('SELECT NOW()');
            console.log('✅ Database is responding to queries');
            
            client.release();
            await pool.end();
            
            console.log('🎉 Database is ready for initialization!');
            return true;
            
        } catch (error) {
            console.log('❌ Database not ready yet:', error.message);
            
            if (attempts >= maxAttempts) {
                console.log('💥 Max connection attempts reached. Database might not be available.');
                await pool.end();
                return false;
            }
            
            // Čekaj 5 sekundi prije sljedećeg pokušaja
            console.log('⏰ Waiting 5 seconds before retry...');
            await new Promise(resolve => setTimeout(resolve, 5000));
        }
    }
    
    await pool.end();
    return false;
}

// Pokreni čekanje ako je skripta pozvana direktno
if (require.main === module) {
    waitForDatabase()
        .then(success => {
            if (success) {
                console.log('🚀 Proceeding with database initialization...');
                process.exit(0);
            } else {
                console.log('💥 Cannot connect to database. Exiting.');
                process.exit(1);
            }
        })
        .catch(error => {
            console.error('💥 Error waiting for database:', error);
            process.exit(1);
        });
}

module.exports = { waitForDatabase };
