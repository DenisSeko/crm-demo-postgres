// start.js (u root direktoriju)
import { initializeDatabase } from './database/init.js';
import './server.js';

async function start() {
    console.log('🚀 Starting CRM Backend Application...');
    
    try {
        // Prvo inicijaliziraj bazu
        console.log('📦 Initializing database...');
        const dbSuccess = await initializeDatabase();
        
        if (dbSuccess) {
            console.log('✅ Database ready');
        } else {
            console.log('⚠️ Database initialization had issues, but continuing...');
        }
        
        // Server će se automatski pokrenuti preko importa server.js
        console.log('🎉 Application startup sequence completed');
        
    } catch (error) {
        console.error('❌ Failed to start application:', error);
        process.exit(1);
    }
}

start();