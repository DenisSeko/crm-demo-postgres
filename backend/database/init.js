const { setupDatabase } = require('./setup');
require('dotenv').config();

async function initializeDatabase() {
    console.log('🗄️  Starting database initialization...');
    
    try {
        await setupDatabase();
        console.log('🎉 Database initialization completed successfully!');
    } catch (error) {
        console.error('❌ Database initialization failed:', error.message);
        throw error;
    }
}

// Pokreni inicijalizaciju ako je skripta pozvana direktno
if (require.main === module) {
    initializeDatabase()
        .then(() => {
            console.log('🚀 Init process completed');
            process.exit(0);
        })
        .catch(error => {
            console.error('💥 Init process failed');
            process.exit(1);
        });
}

module.exports = { initializeDatabase };
