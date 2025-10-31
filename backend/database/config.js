import pkg from 'pg';
const { Pool } = pkg;

export const pool = new Pool({
  user: 'crm_user',
  host: 'localhost',
  database: 'crm_demo',
  password: 'crm_password',
  port: 5433,
});

// Graceful shutdown
process.on('SIGINT', async () => {
  await pool.end();
  process.exit(0);
});
