console.log('🔍 BASIC CHECK: Starting environment check...');

// Check Node.js version
console.log('🔍 Node.js version:', process.version);

// Check if we're in production
console.log('🔍 NODE_ENV:', process.env.NODE_ENV || 'not set');

// Check critical environment variables
console.log('🔍 PORT:', process.env.PORT || 'not set');

// Check for DATABASE_URL - this is the main issue!
console.log('🔍 DATABASE_URL exists:', !!process.env.DATABASE_URL);
if (process.env.DATABASE_URL) {
    const safeUrl = process.env.DATABASE_URL.replace(/:[^:]*@/, ':****@');
    console.log('🔍 DATABASE_URL (safe):', safeUrl);
    
    // Test if it's a valid PostgreSQL URL
    if (process.env.DATABASE_URL.includes('postgres://') || process.env.DATABASE_URL.includes('postgresql://')) {
        console.log('✅ DATABASE_URL looks like a valid PostgreSQL URL');
    } else {
        console.log('❌ DATABASE_URL does not look like a PostgreSQL URL');
    }
} else {
    console.log('❌ DATABASE_URL is NOT SET!');
    console.log('🔍 All environment variables:');
    Object.keys(process.env).forEach(key => {
        console.log('   ', key, ':', process.env[key] ? '***SET***' : 'NOT SET');
    });
}

// Check if required files exist
const fs = require('fs');
const path = require('path');

console.log('🔍 Checking required files...');
const requiredFiles = [
    'package.json',
    'server.js', 
    'database/setup.js',
    'database/schema.sql'
];

requiredFiles.forEach(file => {
    const filePath = path.join(__dirname, '..', file);
    const exists = fs.existsSync(filePath);
    console.log(exists ? '✅' : '❌', file, exists ? 'EXISTS' : 'MISSING');
    if (!exists && file === 'database/schema.sql') {
        console.log('   Current directory:', __dirname);
        console.log('   Files in database directory:');
        try {
            const files = fs.readdirSync(path.join(__dirname));
            files.forEach(f => console.log('     -', f));
        } catch (e) {
            console.log('   Cannot read database directory:', e.message);
        }
    }
});

console.log('🎉 BASIC CHECK: Environment check completed');
process.exit(0);
