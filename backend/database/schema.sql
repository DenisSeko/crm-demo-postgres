-- backend/database/schema.sql
-- CRM Database Schema with Demo Data for PostgreSQL

-- Tablica korisnika za autentikaciju
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    role VARCHAR(20) DEFAULT 'user' CHECK (role IN ('admin', 'user')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tablica klijenata
CREATE TABLE IF NOT EXISTS clients (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    company VARCHAR(100),
    phone VARCHAR(20),
    address TEXT,
    created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tablica bilješki
CREATE TABLE IF NOT EXISTS notes (
    id SERIAL PRIMARY KEY,
    client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tablica aktivnosti (dodatna funkcionalnost)
CREATE TABLE IF NOT EXISTS activities (
    id SERIAL PRIMARY KEY,
    client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL CHECK (type IN ('call', 'email', 'meeting', 'note', 'other')),
    description TEXT NOT NULL,
    activity_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Ubacivanje demo korisnika (lozinka je "password123" hashana)
INSERT INTO users (username, email, password_hash, first_name, last_name, role) VALUES
('admin', 'admin@crm.com', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Admin', 'Korisnik', 'admin'),
('ivan.horvat', 'ivan.horvat@primjer.hr', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Ivan', 'Horvat', 'user'),
('ana.kovač', 'ana.kovac@primjer.hr', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Ana', 'Kovač', 'user'),
('marko.petrov', 'marko.petrov@primjer.hr', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Marko', 'Petrov', 'user')
ON CONFLICT (email) DO NOTHING;

-- Ubacivanje demo klijenata
INSERT INTO clients (name, email, company, phone, address, created_by) VALUES
('Tech Solutions d.o.o.', 'info@techsolutions.hr', 'Tech Solutions', '+385 1 2345 678', 'Ilica 123, 10000 Zagreb', 1),
('Web Studio Pro', 'contact@webstudiopro.hr', 'Web Studio Pro', '+385 1 3456 789', 'Vlaška 45, 10000 Zagreb', 2),
('Digital Agency', 'hello@digitalagency.hr', 'Digital Agency', '+385 1 4567 890', 'Trg bana Jelačića 15, 10000 Zagreb', 1),
('IT Consulting', 'office@itconsulting.hr', 'IT Consulting', '+385 1 5678 901', 'Heinzelova 25, 10000 Zagreb', 3),
('Software House', 'info@softwarehouse.hr', 'Software House', '+385 1 6789 012', 'Vukovarska 178, 10000 Zagreb', 2),
('Design Studio', 'studio@designstudio.hr', 'Design Studio', '+385 1 7890 123', 'Prilaz Gjure Deželića 27, 10000 Zagreb', 4),
('Marketing Experts', 'contact@marketingexperts.hr', 'Marketing Experts', '+385 1 8901 234', 'Avenija Dubrovnik 15, 10000 Zagreb', 1),
('Cloud Services', 'info@cloudservices.hr', 'Cloud Services', '+385 1 9012 345', 'Jadranska avenija 32, 10000 Zagreb', 3),
('Data Analytics', 'hello@dataanalytics.hr', 'Data Analytics', '+385 1 0123 456', 'Slavonska avenija 12, 10000 Zagreb', 2),
('Mobile Dev Team', 'team@mobiledev.hr', 'Mobile Dev Team', '+385 1 1234 567', 'Vrbani 3, 10000 Zagreb', 4)
ON CONFLICT (email) DO NOTHING;

-- Ubacivanje demo bilješki
INSERT INTO notes (client_id, content, created_by) VALUES
(1, 'Klijent zainteresiran za nadogradnju web stranice. Dogovoren sastanak sljedeći tjedan.', 1),
(1, 'Poslana ponuda za redesign web stranice. Čekamo povratnu informaciju.', 2),
(2, 'Klijent zadovoljan trenutnim rezultatima. Razgovarali o mogućnostima proširenja suradnje.', 3),
(3, 'Problemi s hostingom. Riješeno prebacivanje na novi server.', 1),
(4, 'Početna analiza poslovanja. Pripremljen detaljan izvještaj.', 4),
(4, 'Klijent traži dodatne mogućnosti u CRM sustavu. Pripremiti demo za sljedeći tjedan.', 2),
(5, 'Usvojena nova funkcionalnost. Početi s implementacijom.', 3),
(6, 'Klijent predložio promjenu boja u dizajnu. Poslati prijedloge.', 1),
(7, 'Razgovor o digitalnoj marketinškoj strategiji za sljedeći kvartal.', 4),
(8, 'Migracija podataka završena. Testiranje u toku.', 2),
(9, 'Klijent zatražio analizu podataka za posljednju godinu.', 3),
(10, 'Razvoj mobilne aplikacije u završnoj fazi. Priprema za launch.', 1),
(2, 'Novi zahtjevi za funkcionalnostima. Analiza u tijeku.', 2),
(3, 'Klijent pohvalio brzinu odgovora na pitanja.', 4),
(5, 'Planiranje treninga za korisnike za sljedeći mjesec.', 1);

-- Ubacivanje demo aktivnosti
INSERT INTO activities (client_id, type, description, activity_date, created_by) VALUES
(1, 'meeting', 'Sastanak o nadogradnji web stranice', '2024-01-15 10:00:00', 1),
(2, 'call', 'Telefonski razgovor o novim zahtjevima', '2024-01-16 14:30:00', 2),
(3, 'email', 'Slanje tehničke dokumentacije', '2024-01-17 09:15:00', 3),
(4, 'meeting', 'Demo prezentacija novih funkcionalnosti', '2024-01-18 11:00:00', 1),
(5, 'call', 'Konsultacije o optimizaciji performansi', '2024-01-19 16:45:00', 4),
(1, 'email', 'Slanje ponude za redesign', '2024-01-20 13:20:00', 2),
(6, 'meeting', 'Razgovor o rebrandingu', '2024-01-21 10:30:00', 3),
(7, 'call', 'Analiza rezultata marketinške kampanje', '2024-01-22 15:00:00', 1),
(8, 'email', 'Uputstva za korištenje novog sustava', '2024-01-23 08:45:00', 4),
(9, 'meeting', 'Prezentacija analize podataka', '2024-01-24 12:00:00', 2);

-- Kreiranje indeksa za bolju performansu
CREATE INDEX IF NOT EXISTS idx_clients_email ON clients(email);
CREATE INDEX IF NOT EXISTS idx_notes_client_id ON notes(client_id);
CREATE INDEX IF NOT EXISTS idx_notes_created_at ON notes(created_at);
CREATE INDEX IF NOT EXISTS idx_activities_client_id ON activities(client_id);
CREATE INDEX IF NOT EXISTS idx_activities_date ON activities(activity_date);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- Prikaz broja unosa po tablicama (za provjeru)
SELECT 'Users' as table_name, COUNT(*) as count FROM users
UNION ALL
SELECT 'Clients', COUNT(*) FROM clients
UNION ALL
SELECT 'Notes', COUNT(*) FROM notes
UNION ALL
SELECT 'Activities', COUNT(*) FROM activities;