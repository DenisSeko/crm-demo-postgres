FROM node:18-alpine

WORKDIR /app

# Kopiraj package fajlove
COPY backend/package*.json ./

# Instaliraj zavisnosti
RUN npm install --production

# Kopiraj backend kod
COPY backend/ ./

# Prvo čekaj na bazu, pa pokreni setup
CMD ["sh", "-c", "echo '🚀 Starting application...' && npm run start:with-db"]

EXPOSE 3001
