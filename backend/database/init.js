// database/init.js
import { Pool } from 'pg';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function initializeDatabase() {
    console.log('🚀 Starting database initialization...');
    
    if (!process.env.DATABASE_URL) {
        console.error('❌ DATABASE_URL not set');
        return; // Nemoj failati, možda nije potrebno
    }

    console.log('🔗 Database URL:', process.env.DATABASE_URL.replace(/:[^:]*@/, ':***@'));

    const pool = new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: { rejectUnauthorized: false }
    });

    let client;
    try {
        console.log('🔗 Testing database connection...');
        client = await pool.connect();
        
        // Test connection
        const result = await client.query('SELECT version()');
        console.log('✅ Database connected successfully');
        
        // Pronađi schema.sql
        const schemaPath = findSchemaFile();
        
        if (schemaPath) {
            console.log(`📄 Found schema file: ${schemaPath}`);
            await importSchema(client, schemaPath);
        } else {
            console.log('⚠️ No schema file found, checking existing tables...');
            await checkExistingTables(client);
        }

        console.log('🎉 Database initialization completed!');
        
    } catch (error) {
        console.error('❌ Database initialization failed:', error.message);
        // Nemoj failati - možda baza već postoji ili nije dostupna
    } finally {
        if (client) {
            client.release();
        }
        await pool.end();
    }
}

function findSchemaFile() {
    const possiblePaths = [
        path.join(process.cwd(), 'database', 'schema.sql'),
        path.join(process.cwd(), 'schema.sql'),
        path.join(__dirname, 'schema.sql'),
        'schema.sql'
    ];
    
    for (const schemaPath of possiblePaths) {
        if (fs.existsSync(schemaPath)) {
            return schemaPath;
        }
    }
    
    console.log('📁 Searched paths:', possiblePaths);
    return null;
}

async function importSchema(client, schemaPath) {
    try {
        const schemaSQL = fs.readFileSync(schemaPath, 'utf8');
        console.log(`📊 Importing schema (${schemaSQL.length} characters)...`);
        
        // Podijeli SQL naredbe
        const statements = schemaSQL
            .split(';')
            .map(stmt => stmt.trim())
            .filter(stmt => stmt.length > 0 && !stmt.startsWith('--'));
        
        console.log(`📝 Found ${statements.length} SQL statements`);
        
        for (let i = 0; i < statements.length; i++) {
            const statement = statements[i] + ';';
            try {
                await client.query(statement);
                console.log(`✅ Executed statement ${i + 1}/${statements.length}`);
            } catch (error) {
                console.error(`❌ Error in statement ${i + 1}:`, error.message);
                // Nastavi s sljedećom naredbom
            }
        }
        
        console.log('✅ Schema import completed');
        
    } catch (error) {
        console.error('❌ Schema import failed:', error.message);
    }
}

async function checkExistingTables(client) {
    try {
        const result = await client.query(`
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
            ORDER BY table_name
        `);
        
        console.log(`📊 Found ${result.rows.length} existing tables:`);
        result.rows.forEach(row => console.log(`   - ${row.table_name}`));
        
        if (result.rows.length === 0) {
            console.log('ℹ️ No tables found, database is empty');
        }
        
    } catch (error) {
        console.error('❌ Error checking tables:', error.message);
    }
}

// Pokreni inicijalizaciju
initializeDatabase().catch(error => {
    console.error('Failed to initialize database:', error);
});