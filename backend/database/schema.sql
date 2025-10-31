-- Simple CRM Schema for Railway PostgreSQL
-- This should work without any issues

CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS clients (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    company VARCHAR(255),
    owner_id INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS notes (
    id SERIAL PRIMARY KEY,
    content TEXT NOT NULL,
    client_id INTEGER REFERENCES clients(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert demo data (safe with ON CONFLICT)
INSERT INTO users (email, password, name) 
VALUES ('demo@demo.com', 'demo123', 'Demo User')
ON CONFLICT (email) DO NOTHING;

INSERT INTO clients (name, email, company, owner_id) 
VALUES 
    ('John Doe', 'john@example.com', 'ABC Company', 1),
    ('Jane Smith', 'jane@example.com', 'XYZ Corp', 1)
ON CONFLICT (email) DO NOTHING;

INSERT INTO notes (content, client_id) 
VALUES 
    ('First meeting completed', 1),
    ('Follow up scheduled', 1),
    ('Product demo requested', 2)
ON CONFLICT DO NOTHING;
