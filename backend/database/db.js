const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
    // Retry logika za production
    ...(process.env.NODE_ENV === 'production' && {
        connectionTimeoutMillis: 10000,
        idleTimeoutMillis: 30000,
        max: 20
    })
});

// Test connection on startup
pool.on('connect', () => {
    console.log('✅ Connected to PostgreSQL database');
});

pool.on('error', (err) => {
    console.error('❌ PostgreSQL connection error:', err);
});

// Funkcija za retry connection
const queryWithRetry = async (text, params, retries = 3) => {
    for (let i = 0; i < retries; i++) {
        try {
            return await pool.query(text, params);
        } catch (error) {
            if (i === retries - 1) throw error;
            console.log('🔄 Query failed, retrying...', error.message);
            await new Promise(resolve => setTimeout(resolve, 1000 * (i + 1)));
        }
    }
};

module.exports = {
    query: queryWithRetry,
    pool
};
