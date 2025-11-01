// database/init.js
import { pool } from './config.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export async function initializeDatabase() {
    console.log('🚀 Starting database initialization...');
    
    let client;
    try {
        console.log('🔗 Testing database connection...');
        client = await pool.connect();
        
        // Test connection
        const result = await client.query('SELECT version()');
        console.log('✅ Database connected:', result.rows[0].version);
        
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
        return true;
        
    } catch (error) {
        console.error('❌ Database initialization failed:', error.message);
        return false;
    } finally {
        if (client) {
            client.release();
        }
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
    
    console.log('📁 Searched in:', possiblePaths);
    return null;
}

async function importSchema(client, schemaPath) {
    try {
        const schemaSQL = fs.readFileSync(schemaPath, 'utf8');
        console.log(`📊 Importing schema (${schemaSQL.length} chars)...`);
        
        await client.query(schemaSQL);
        console.log('✅ Schema imported successfully');
        
    } catch (error) {
        console.error('❌ Schema import failed:', error.message);
        // Možda tabele već postoje, to je OK
    }
}

async function checkExistingTables(client) {
    try {
        const result = await client.query(`
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
        `);
        
        console.log(`📊 Found ${result.rows.length} existing tables:`);
        result.rows.forEach(row => console.log(`   - ${row.table_name}`));
        
    } catch (error) {
        console.error('❌ Error checking tables:', error.message);
    }
}

// Samo pokreni ako je direktno pozvan
if (import.meta.url === `file://${process.argv[1]}`) {
    initializeDatabase();
}