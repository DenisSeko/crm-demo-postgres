import pkg from 'pg';
import bcrypt from 'bcrypt';

const { Pool } = pkg;

// Database configuration from Docker environment variables
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://crm_user:crm_password@localhost:5433/crm_demo',
  ssl: false
});

async function initializeDatabase() {
  let dbClient; // Promijenio ime varijable da se ne brka sa client objektima
  
  try {
    console.log('🚀 Starting database initialization...');
    console.log('📊 Database:', process.env.DATABASE_URL || 'postgresql://crm_user:crm_password@localhost:5433/crm_demo');
    
    dbClient = await pool.connect();
    console.log('✅ Connected to database');

    // Kreiranje tablica ako ne postoje
    console.log('📋 Creating tables if they don\'t exist...');
    
    await dbClient.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        username VARCHAR(50) UNIQUE NOT NULL,
        email VARCHAR(100) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        first_name VARCHAR(50),
        last_name VARCHAR(50),
        role VARCHAR(20) DEFAULT 'user',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await dbClient.query(`
      CREATE TABLE IF NOT EXISTS clients (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(100) UNIQUE NOT NULL,
        company VARCHAR(100),
        phone VARCHAR(20),
        address TEXT,
        created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await dbClient.query(`
      CREATE TABLE IF NOT EXISTS notes (
        id SERIAL PRIMARY KEY,
        client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
        content TEXT NOT NULL,
        created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    await dbClient.query(`
      CREATE TABLE IF NOT EXISTS activities (
        id SERIAL PRIMARY KEY,
        client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
        type VARCHAR(20) NOT NULL CHECK (type IN ('call', 'email', 'meeting', 'note', 'other')),
        description TEXT NOT NULL,
        activity_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    console.log('✅ Tables created/verified');

    // Ubacivanje demo korisnika
    console.log('👥 Inserting demo users...');
    
    const demoUsers = [
      {
        username: 'admin',
        email: 'admin@crm.com',
        password: 'password123',
        firstName: 'Admin',
        lastName: 'Korisnik',
        role: 'admin'
      },
      {
        username: 'ivan.horvat',
        email: 'ivan.horvat@primjer.hr',
        password: 'password123',
        firstName: 'Ivan',
        lastName: 'Horvat',
        role: 'user'
      },
      {
        username: 'ana.kovac',
        email: 'ana.kovac@primjer.hr',
        password: 'password123',
        firstName: 'Ana',
        lastName: 'Kovač',
        role: 'user'
      },
      {
        username: 'marko.petrov',
        email: 'marko.petrov@primjer.hr',
        password: 'password123',
        firstName: 'Marko',
        lastName: 'Petrov',
        role: 'user'
      }
    ];

    for (const user of demoUsers) {
      const passwordHash = await bcrypt.hash(user.password, 10);
      
      await dbClient.query(`
        INSERT INTO users (username, email, password_hash, first_name, last_name, role) 
        VALUES ($1, $2, $3, $4, $5, $6)
        ON CONFLICT (email) DO UPDATE SET
          username = EXCLUDED.username,
          password_hash = EXCLUDED.password_hash,
          first_name = EXCLUDED.first_name,
          last_name = EXCLUDED.last_name,
          role = EXCLUDED.role,
          updated_at = CURRENT_TIMESTAMP
      `, [user.username, user.email, passwordHash, user.firstName, user.lastName, user.role]);
    }

    console.log('✅ Demo users inserted/updated');

    // Ubacivanje demo klijenata
    console.log('🏢 Inserting demo clients...');
    
    const demoClients = [
      {
        name: 'Tech Solutions d.o.o.',
        email: 'info@techsolutions.hr',
        company: 'Tech Solutions',
        phone: '+385 1 2345 678',
        address: 'Ilica 123, 10000 Zagreb',
        createdBy: 1
      },
      {
        name: 'Web Studio Pro',
        email: 'contact@webstudiopro.hr',
        company: 'Web Studio Pro',
        phone: '+385 1 3456 789',
        address: 'Vlaška 45, 10000 Zagreb',
        createdBy: 2
      },
      {
        name: 'Digital Agency',
        email: 'hello@digitalagency.hr',
        company: 'Digital Agency',
        phone: '+385 1 4567 890',
        address: 'Trg bana Jelačića 15, 10000 Zagreb',
        createdBy: 1
      },
      {
        name: 'IT Consulting',
        email: 'office@itconsulting.hr',
        company: 'IT Consulting',
        phone: '+385 1 5678 901',
        address: 'Heinzelova 25, 10000 Zagreb',
        createdBy: 3
      },
      {
        name: 'Software House',
        email: 'info@softwarehouse.hr',
        company: 'Software House',
        phone: '+385 1 6789 012',
        address: 'Vukovarska 178, 10000 Zagreb',
        createdBy: 2
      },
      {
        name: 'Design Studio',
        email: 'studio@designstudio.hr',
        company: 'Design Studio',
        phone: '+385 1 7890 123',
        address: 'Prilaz Gjure Deželića 27, 10000 Zagreb',
        createdBy: 4
      },
      {
        name: 'Marketing Experts',
        email: 'contact@marketingexperts.hr',
        company: 'Marketing Experts',
        phone: '+385 1 8901 234',
        address: 'Avenija Dubrovnik 15, 10000 Zagreb',
        createdBy: 1
      },
      {
        name: 'Cloud Services',
        email: 'info@cloudservices.hr',
        company: 'Cloud Services',
        phone: '+385 1 9012 345',
        address: 'Jadranska avenija 32, 10000 Zagreb',
        createdBy: 3
      },
      {
        name: 'Data Analytics',
        email: 'hello@dataanalytics.hr',
        company: 'Data Analytics',
        phone: '+385 1 0123 456',
        address: 'Slavonska avenija 12, 10000 Zagreb',
        createdBy: 2
      },
      {
        name: 'Mobile Dev Team',
        email: 'team@mobiledev.hr',
        company: 'Mobile Dev Team',
        phone: '+385 1 1234 567',
        address: 'Vrbani 3, 10000 Zagreb',
        createdBy: 4
      }
    ];

    for (const clientData of demoClients) { // Promijenio ime varijable
      await dbClient.query(`
        INSERT INTO clients (name, email, company, phone, address, created_by) 
        VALUES ($1, $2, $3, $4, $5, $6)
        ON CONFLICT (email) DO UPDATE SET
          name = EXCLUDED.name,
          company = EXCLUDED.company,
          phone = EXCLUDED.phone,
          address = EXCLUDED.address,
          updated_at = CURRENT_TIMESTAMP
      `, [clientData.name, clientData.email, clientData.company, clientData.phone, clientData.address, clientData.createdBy]);
    }

    console.log('✅ Demo clients inserted/updated');

    // Ubacivanje demo bilješki
    console.log('📝 Inserting demo notes...');
    
    const demoNotes = [
      { clientId: 1, content: 'Klijent zainteresiran za nadogradnju web stranice. Dogovoren sastanak sljedeći tjedan.', createdBy: 1 },
      { clientId: 1, content: 'Poslana ponuda za redesign web stranice. Čekamo povratnu informaciju.', createdBy: 2 },
      { clientId: 2, content: 'Klijent zadovoljan trenutnim rezultatima. Razgovarali o mogućnostima proširenja suradnje.', createdBy: 3 },
      { clientId: 3, content: 'Problemi s hostingom. Riješeno prebacivanje na novi server.', createdBy: 1 },
      { clientId: 4, content: 'Početna analiza poslovanja. Pripremljen detaljan izvještaj.', createdBy: 4 },
      { clientId: 4, content: 'Klijent traži dodatne mogućnosti u CRM sustavu. Pripremiti demo za sljedeći tjedan.', createdBy: 2 },
      { clientId: 5, content: 'Usvojena nova funkcionalnost. Početi s implementacijom.', createdBy: 3 },
      { clientId: 6, content: 'Klijent predložio promjenu boja u dizajnu. Poslati prijedloge.', createdBy: 1 },
      { clientId: 7, content: 'Razgovor o digitalnoj marketinškoj strategiji za sljedeći kvartal.', createdBy: 4 },
      { clientId: 8, content: 'Migracija podataka završena. Testiranje u toku.', createdBy: 2 },
      { clientId: 9, content: 'Klijent zatražio analizu podataka za posljednju godinu.', createdBy: 3 },
      { clientId: 10, content: 'Razvoj mobilne aplikacije u završnoj fazi. Priprema za launch.', createdBy: 1 },
      { clientId: 2, content: 'Novi zahtjevi za funkcionalnostima. Analiza u tijeku.', createdBy: 2 },
      { clientId: 3, content: 'Klijent pohvalio brzinu odgovora na pitanja.', createdBy: 4 },
      { clientId: 5, content: 'Planiranje treninga za korisnike za sljedeći mjesec.', createdBy: 1 }
    ];

    for (const note of demoNotes) {
      await dbClient.query(`
        INSERT INTO notes (client_id, content, created_by) 
        VALUES ($1, $2, $3)
        ON CONFLICT DO NOTHING
      `, [note.clientId, note.content, note.createdBy]);
    }

    console.log('✅ Demo notes inserted');

    // Ubacivanje demo aktivnosti
    console.log('📅 Inserting demo activities...');
    
    const demoActivities = [
      { clientId: 1, type: 'meeting', description: 'Sastanak o nadogradnji web stranice', activityDate: '2024-01-15 10:00:00', createdBy: 1 },
      { clientId: 2, type: 'call', description: 'Telefonski razgovor o novim zahtjevima', activityDate: '2024-01-16 14:30:00', createdBy: 2 },
      { clientId: 3, type: 'email', description: 'Slanje tehničke dokumentacije', activityDate: '2024-01-17 09:15:00', createdBy: 3 },
      { clientId: 4, type: 'meeting', description: 'Demo prezentacija novih funkcionalnosti', activityDate: '2024-01-18 11:00:00', createdBy: 1 },
      { clientId: 5, type: 'call', description: 'Konsultacije o optimizaciji performansi', activityDate: '2024-01-19 16:45:00', createdBy: 4 },
      { clientId: 1, type: 'email', description: 'Slanje ponude za redesign', activityDate: '2024-01-20 13:20:00', createdBy: 2 },
      { clientId: 6, type: 'meeting', description: 'Razgovor o rebrandingu', activityDate: '2024-01-21 10:30:00', createdBy: 3 },
      { clientId: 7, type: 'call', description: 'Analiza rezultata marketinške kampanje', activityDate: '2024-01-22 15:00:00', createdBy: 1 },
      { clientId: 8, type: 'email', description: 'Uputstva za korištenje novog sustava', activityDate: '2024-01-23 08:45:00', createdBy: 4 },
      { clientId: 9, type: 'meeting', description: 'Prezentacija analize podataka', activityDate: '2024-01-24 12:00:00', createdBy: 2 }
    ];

    for (const activity of demoActivities) {
      await dbClient.query(`
        INSERT INTO activities (client_id, type, description, activity_date, created_by) 
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT DO NOTHING
      `, [activity.clientId, activity.type, activity.description, activity.activityDate, activity.createdBy]);
    }

    console.log('✅ Demo activities inserted');

    // Kreiranje indeksa
    console.log('📊 Creating indexes...');
    
    await dbClient.query('CREATE INDEX IF NOT EXISTS idx_clients_email ON clients(email)');
    await dbClient.query('CREATE INDEX IF NOT EXISTS idx_notes_client_id ON notes(client_id)');
    await dbClient.query('CREATE INDEX IF NOT EXISTS idx_notes_created_at ON notes(created_at)');
    await dbClient.query('CREATE INDEX IF NOT EXISTS idx_activities_client_id ON activities(client_id)');
    await dbClient.query('CREATE INDEX IF NOT EXISTS idx_activities_date ON activities(activity_date)');
    await dbClient.query('CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)');

    console.log('✅ Indexes created');

    // Prikaz statistike
    const usersCount = await dbClient.query('SELECT COUNT(*) FROM users');
    const clientsCount = await dbClient.query('SELECT COUNT(*) FROM clients');
    const notesCount = await dbClient.query('SELECT COUNT(*) FROM notes');
    const activitiesCount = await dbClient.query('SELECT COUNT(*) FROM activities');

    console.log('\n📈 Database Statistics:');
    console.log(`👥 Users: ${usersCount.rows[0].count}`);
    console.log(`🏢 Clients: ${clientsCount.rows[0].count}`);
    console.log(`📝 Notes: ${notesCount.rows[0].count}`);
    console.log(`📅 Activities: ${activitiesCount.rows[0].count}`);

    console.log('\n🎉 Database initialization completed successfully!');
    console.log('\n🔐 Demo login credentials:');
    console.log('   admin@crm.com / password123 (admin)');
    console.log('   ivan.horvat@primjer.hr / password123 (user)');
    console.log('   ana.kovac@primjer.hr / password123 (user)');
    console.log('   marko.petrov@primjer.hr / password123 (user)');

  } catch (error) {
    console.error('💥 Error during database initialization:', error);
    throw error;
  } finally {
    if (dbClient) {
      dbClient.release();
    }
    await pool.end();
  }
}

// Pokretanje inicijalizacije
initializeDatabase().catch(error => {
  console.error('💥 Failed to initialize database:', error);
  process.exit(1);
});