FROM node:18-alpine

WORKDIR /app

# Kopiraj backend package fajlove
COPY backend/package*.json ./

# Instaliraj zavisnosti
RUN npm install --production

# Kopiraj CIJELI backend folder
COPY backend/ ./

# Kopiraj database schema
COPY database/schema.sql ./database/schema.sql

# Pokreni wait-for-db PRVO, pa init, pa server
CMD ["sh", "-c", "echo '🚀 Starting application...' && npm run db:wait && echo '✅ Database ready, running init...' && npm run db:init && echo '🎉 Starting server...' && npm start"]

EXPOSE 3001
