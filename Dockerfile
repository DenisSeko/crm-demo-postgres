FROM node:18-alpine

WORKDIR /app

# Kopiraj backend package fajlove
COPY backend/package*.json ./

# Instaliraj zavisnosti
RUN npm install --production

# Kopiraj CIJELI backend folder
COPY backend/ ./

# Kopiraj database schema u DVIJE lokacije za sigurnost
COPY database/ ./database/
COPY database/schema.sql ./schema.sql

# Pokreni init skriptu pri pokretanju
CMD ["sh", "-c", "npm run db:init && npm start"]

EXPOSE 3001
