console.log('🚀 START-WITH-DB: Starting application with database check...');

// Prvo pričekaj da DATABASE_URL bude dostupan
require('./wait-for-db.js').then(() => {
    // Sada pokreni setup
    console.log('📦 Running database setup...');
    require('./setup.js');
}).catch(error => {
    console.log('💥 Cannot start without database');
    process.exit(1);
});
