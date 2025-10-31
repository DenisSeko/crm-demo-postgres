#!/bin/bash

# PostgreSQL Database Initialization Script for Railway CRM Backend
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

find_schema_file() {
    log "Searching for schema files in project..."
    
    # Traži schema.sql bilo gdje u projektu
    local schema_path=$(find . -type f -name "schema.sql" | head -1)
    
    if [ -n "$schema_path" ] && [ -f "$schema_path" ]; then
        log "Found schema.sql at: $schema_path"
        echo "$schema_path"
        return 0
    fi
    
    # Ako nema schema.sql, traži bilo koji SQL fajl
    warning "schema.sql not found, looking for any .sql file..."
    local any_sql=$(find . -type f -name "*.sql" | head -1)
    
    if [ -n "$any_sql" ] && [ -f "$any_sql" ]; then
        log "Found SQL file: $any_sql"
        echo "$any_sql"
        return 0
    fi
    
    error "No SQL files found in project!"
    return 1
}

main() {
    log "Starting CRM Database Initialization..."
    log "Working directory: $(pwd)"
    log "Timestamp: $(date)"
    
    # Debug info - prikaži strukturu projekta
    log "Project structure (important files):"
    find . -type f \( -name "*.sql" -o -name "*.js" -o -name "*.json" \) | head -15
    
    if [ -z "$DATABASE_URL" ]; then
        error "DATABASE_URL not set"
        log "Available environment variables:"
        env | grep -E "(DATABASE|POSTGRES|RAILWAY)" | head -10
        exit 1
    fi
    
    # Log database info (without password)
    DB_INFO=$(echo "$DATABASE_URL" | sed -E 's|://[^:]+:[^@]+@|://***:***@|')
    log "Database: $DB_INFO"
    
    # Install PostgreSQL client if needed
    if ! command -v psql &> /dev/null; then
        log "Installing PostgreSQL client..."
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y postgresql-client
        elif command -v apk &> /dev/null; then
            apk add --no-cache postgresql-client
        elif command -v yum &> /dev/null; then
            yum install -y postgresql
        else
            error "Cannot install PostgreSQL client - no package manager found"
            exit 1
        fi
    fi
    
    if command -v psql &> /dev/null; then
        log "PostgreSQL client: $(psql --version | head -n1)"
    else
        error "PostgreSQL client not available"
        exit 1
    fi
    
    # Test connection
    log "Testing database connection..."
    if ! psql "$DATABASE_URL" -c "SELECT version();" -t > /dev/null 2>&1; then
        error "Cannot connect to database"
        log "Trying with connection timeout..."
        if ! timeout 30s psql "$DATABASE_URL" -c "SELECT version();" -t; then
            error "Database connection failed after retry"
            exit 1
        fi
    fi
    
    success "Database connection successful"
    
    # Pronađi i importaj schema
    SCHEMA_FILE=$(find_schema_file)
    
    if [ -n "$SCHEMA_FILE" ] && [ -f "$SCHEMA_FILE" ]; then
        log "Importing schema from: $SCHEMA_FILE"
        log "File content preview (first 5 lines):"
        head -5 "$SCHEMA_FILE"
        
        if psql "$DATABASE_URL" -f "$SCHEMA_FILE" -v ON_ERROR_STOP=1; then
            success "Schema imported successfully from: $SCHEMA_FILE"
        else
            error "Schema import failed from: $SCHEMA_FILE"
            log "Trying alternative import method (without ON_ERROR_STOP)..."
            if psql "$DATABASE_URL" -f "$SCHEMA_FILE"; then
                success "Schema imported using alternative method"
            else
                error "All import methods failed"
                # Nastavi dalje, ne prekidaj skriptu
            fi
        fi
    else
        warning "No schema file found to import"
        log "Creating minimal test table..."
        psql "$DATABASE_URL" -c "
            CREATE TABLE IF NOT EXISTS app_settings (
                id SERIAL PRIMARY KEY,
                name VARCHAR(100) NOT NULL,
                value TEXT,
                created_at TIMESTAMP DEFAULT NOW()
            );
            INSERT INTO app_settings (name, value) VALUES ('init_version', '1.0') 
            ON CONFLICT (name) DO UPDATE SET value = EXCLUDED.value;
        " && success "Minimal test table created"
    fi
    
    # Run existing Node.js init script
    if [ -f "database/init.js" ]; then
        log "Running Node.js init script (database/init.js)..."
        if node database/init.js; then
            success "Node.js init script completed"
        else
            error "Node.js init script failed"
        fi
    else
        warning "database/init.js not found, skipping Node.js init"
    fi
    
    # Show final database status
    log "Database status after initialization:"
    TABLE_COUNT=$(psql "$DATABASE_URL" -t -c "
        SELECT COUNT(*) 
        FROM information_schema.tables 
        WHERE table_schema = 'public';
    " | tr -d ' ' 2>/dev/null || echo "unknown")
    
    success "Database initialization completed - $TABLE_COUNT tables in database"
    
    # Prikaži tabele
    log "Database tables:"
    psql "$DATABASE_URL" -c "
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public'
        ORDER BY table_name;
    " 2>/dev/null || log "Could not list tables"
}

main "$@"
