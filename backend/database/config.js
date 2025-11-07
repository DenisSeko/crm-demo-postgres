import pkg from 'pg';
const { Pool } = pkg;

// Database configuration za Upsun - koristi DATABASE_URL iz environment varijabli
export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

// Graceful shutdown
process.on('SIGINT', async () => {
  await pool.end();
  process.exit(0);
});