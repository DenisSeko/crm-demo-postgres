import { pool } from './config.js';

async function initDatabase() {
  try {
    console.log('🔄 Inicijalizacija baze podataka...');

    // Kreiraj tabele
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        email VARCHAR(255) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL,
        name VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS clients (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) NOT NULL,
        company VARCHAR(255),
        owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS notes (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        content TEXT NOT NULL,
        client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    console.log('✅ Tabele kreirane uspješno');

    // Seed podaci
    const demoPassword = 'demo123';
    
    // Ubaci demo korisnika
    const userResult = await pool.query(
      `INSERT INTO users (email, password, name) 
       VALUES ($1, $2, $3) 
       ON CONFLICT (email) DO NOTHING
       RETURNING id`,
      ['demo@demo.com', demoPassword, 'Demo User']
    );

    if (userResult.rows.length > 0) {
      const userId = userResult.rows[0].id;
      
      // Ubaci demo klijente
      await pool.query(`
        INSERT INTO clients (name, email, company, owner_id) 
        VALUES 
          ('Alpha Corp', 'contact@alpha.com', 'Alpha Corp', $1),
          ('Beta LLC', 'info@beta.com', 'Beta LLC', $1),
          ('Gamma Inc', 'hello@gamma.com', 'Gamma Inc', $1)
        ON CONFLICT DO NOTHING
      `, [userId]);

      // Ubaci demo bilješke
      const clientResult = await pool.query('SELECT id FROM clients LIMIT 1');
      const clientId = clientResult.rows[0]?.id;
      
      if (clientId) {
        await pool.query(`
          INSERT INTO notes (content, client_id) 
          VALUES 
            ('Prvi kontakt - zainteresirani za naš proizvod', $1),
            ('Slanje ponude - čekamo odgovor', $1)
          ON CONFLICT DO NOTHING
        `, [clientId]);
      }

      console.log('✅ Seed podaci dodani uspješno');
    } else {
      console.log('ℹ️  Demo user već postoji');
    }

    console.log('🎉 Baza podataka je spremna!');
    
  } catch (error) {
    console.error('❌ Greška pri inicijalizaciji baze:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

initDatabase();
