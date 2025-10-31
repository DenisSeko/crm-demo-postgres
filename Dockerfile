FROM node:18-alpine

WORKDIR /app

# Kopiraj package fajlove
COPY backend/package*.json ./

# Instaliraj zavisnosti
RUN npm install --production

# Kopiraj backend kod
COPY backend/ ./

# POKRENI SERVER ODMAH - ovo je KLJUČNO!
CMD ["node", "server.js"]

EXPOSE 3001
