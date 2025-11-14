// middleware/auth.js
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'crm_demo_jwt_secret_key_2024_change_in_production';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '24h';
const JWT_ISSUER = process.env.JWT_ISSUER || 'crm-demo-app';

const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    console.log('🔐 Token authentication attempt:', {
        hasToken: !!token,
        path: req.path,
        method: req.method
    });

    if (!token) {
        console.log('❌ No token provided');
        return res.status(401).json({ 
            error: 'Access token je obavezan',
            code: 'MISSING_TOKEN'
        });
    }

    jwt.verify(token, JWT_SECRET, (err, decoded) => {
        if (err) {
            console.log('❌ Token verification failed:', err.name);
            
            let errorMessage = 'Token nije validan';
            let statusCode = 403;
            let errorCode = 'INVALID_TOKEN';

            if (err.name === 'TokenExpiredError') {
                errorMessage = 'Token je istekao';
                statusCode = 401;
                errorCode = 'TOKEN_EXPIRED';
            } else if (err.name === 'JsonWebTokenError') {
                errorMessage = 'Token nije ispravan';
                errorCode = 'MALFORMED_TOKEN';
            }

            return res.status(statusCode).json({ 
                error: errorMessage,
                code: errorCode,
                details: process.env.NODE_ENV === 'development' ? err.message : undefined
            });
        }

        // Dodatna validacija decoded podataka
        if (!decoded.id || !decoded.email || !decoded.role) {
            console.log('❌ Token missing required fields:', decoded);
            return res.status(403).json({ 
                error: 'Token sadrži neispravne podatke',
                code: 'INVALID_TOKEN_PAYLOAD'
            });
        }

        console.log('✅ Token valid for user:', {
            id: decoded.id,
            email: decoded.email,
            role: decoded.role
        });

        req.user = {
            id: decoded.id,
            username: decoded.username,
            email: decoded.email,
            role: decoded.role,
            iat: decoded.iat,
            exp: decoded.exp
        };

        next();
    });
};

const generateToken = (user) => {
    const payload = {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
        iss: JWT_ISSUER,
        iat: Math.floor(Date.now() / 1000)
    };

    const options = {
        expiresIn: JWT_EXPIRES_IN,
        issuer: JWT_ISSUER
    };

    const token = jwt.sign(payload, JWT_SECRET, options);
    
    console.log('🔐 Token generated for user:', {
        id: user.id,
        email: user.email,
        role: user.role,
        expiresIn: JWT_EXPIRES_IN
    });

    return token;
};

const optionalAuth = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        // Ako nema tokena, nastavi bez user objekta
        return next();
    }

    jwt.verify(token, JWT_SECRET, (err, decoded) => {
        if (err) {
            // Ako je token invalid, samo nastavi bez user objekta
            console.log('⚠️ Optional auth - invalid token, continuing without user');
            return next();
        }

        if (decoded.id && decoded.email && decoded.role) {
            req.user = {
                id: decoded.id,
                username: decoded.username,
                email: decoded.email,
                role: decoded.role
            };
            console.log('✅ Optional auth - user authenticated:', req.user.email);
        }

        next();
    });
};

const requireRole = (roles) => {
    return (req, res, next) => {
        if (!req.user) {
            return res.status(401).json({ 
                error: 'Potrebna je prijava',
                code: 'UNAUTHORIZED'
            });
        }

        const userRole = req.user.role;
        const allowedRoles = Array.isArray(roles) ? roles : [roles];

        if (!allowedRoles.includes(userRole)) {
            console.log('❌ Role check failed:', {
                required: allowedRoles,
                userRole: userRole,
                user: req.user.email
            });
            return res.status(403).json({ 
                error: 'Nemate dovoljne privilegije za ovu akciju',
                code: 'INSUFFICIENT_PERMISSIONS'
            });
        }

        console.log('✅ Role check passed:', {
            user: req.user.email,
            role: userRole,
            required: allowedRoles
        });

        next();
    };
};

const decodeTokenWithoutVerification = (token) => {
    try {
        // Ova funkcija samo dekodira token bez verifikacije (korisno za debug)
        const decoded = jwt.decode(token, { complete: true });
        return decoded;
    } catch (error) {
        console.error('Token decoding error:', error);
        return null;
    }
};

const getTokenInfo = (token) => {
    try {
        const decoded = jwt.decode(token);
        if (!decoded) return null;

        const currentTime = Math.floor(Date.now() / 1000);
        const isExpired = decoded.exp < currentTime;
        const timeUntilExpiry = decoded.exp - currentTime;

        return {
            issuedAt: new Date(decoded.iat * 1000),
            expiresAt: new Date(decoded.exp * 1000),
            isExpired,
            timeUntilExpiry,
            userId: decoded.id,
            userEmail: decoded.email,
            userRole: decoded.role
        };
    } catch (error) {
        console.error('Token info error:', error);
        return null;
    }
};

// Middleware za logovanje svih zahtjeva (korisno za debug)
const requestLogger = (req, res, next) => {
    const start = Date.now();
    
    res.on('finish', () => {
        const duration = Date.now() - start;
        const userInfo = req.user ? `[user:${req.user.email}]` : '[anonymous]';
        
        console.log(`${req.method} ${req.originalUrl} ${res.statusCode} ${duration}ms ${userInfo}`);
    });

    next();
};

module.exports = {
    authenticateToken,
    generateToken,
    optionalAuth,
    requireRole,
    decodeTokenWithoutVerification,
    getTokenInfo,
    requestLogger,
    JWT_SECRET,
    JWT_EXPIRES_IN,
    JWT_ISSUER
};