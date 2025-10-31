FROM node:18-alpine

WORKDIR /app

# Kopiraj backend package fajlove
COPY backend/package*.json ./

# Instaliraj zavisnosti
RUN npm install --production

# Kopiraj CIJELI backend folder
COPY backend/ ./
# Kopiraj database schema
COPY database/ ./database/

# Pokreni init skriptu pri pokretanju
CMD ["sh", "-c", "npm run db:init && npm start"]

EXPOSE 3001
