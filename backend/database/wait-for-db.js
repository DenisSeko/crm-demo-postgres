console.log('⏳ WAIT-FOR-DB: Starting...');

let attempts = 0;
const maxAttempts = 60; // 5 minuta (60 * 5 sekundi)

function waitForDatabaseUrl() {
    return new Promise((resolve, reject) => {
        function check() {
            attempts++;
            console.log('🔍 Attempt', attempts, 'of', maxAttempts, '- Checking for DATABASE_URL...');
            
            if (process.env.DATABASE_URL) {
                const safeUrl = process.env.DATABASE_URL.replace(/:[^:]*@/, ':****@');
                console.log('✅ DATABASE_URL found:', safeUrl);
                resolve(true);
                return;
            }
            
            if (attempts >= maxAttempts) {
                console.log('💥 Timeout: DATABASE_URL not available after', maxAttempts, 'attempts');
                console.log('💡 Please check:');
                console.log('   1. Is PostgreSQL service added to your Railway project?');
                console.log('   2. Is PostgreSQL service running?');
                console.log('   3. Wait a few minutes for database to start');
                reject(new Error('DATABASE_URL not available'));
                return;
            }
            
            // Čekaj 5 sekundi prije sljedećeg pokušaja
            console.log('⏰ DATABASE_URL not ready, waiting 5 seconds...');
            setTimeout(check, 5000);
        }
        
        check();
    });
}

// Pokreni čekanje
waitForDatabaseUrl()
    .then(() => {
        console.log('🎉 DATABASE_URL is available! Proceeding with setup...');
        process.exit(0);
    })
    .catch(error => {
        console.log('💥 Failed to get DATABASE_URL');
        process.exit(1);
    });
