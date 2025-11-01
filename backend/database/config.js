import pkg from 'pg';
const { Pool } = pkg;

// Koristi DATABASE_URL od Railwaya, fallback na lokalne postavke
export const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 
    'postgresql://crm_user:crm_password@localhost:5433/crm_demo',
  ssl: process.env.DATABASE_URL ? { rejectUnauthorized: false } : false
});

// Graceful shutdown
process.on('SIGINT', async () => {
  await pool.end();
  process.exit(0);
});
