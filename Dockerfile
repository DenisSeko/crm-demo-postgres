FROM node:18-alpine

WORKDIR /app

# Kopiraj package fajlove
COPY backend/package*.json ./

# Instaliraj zavisnosti
RUN npm install --production

# Kopiraj backend kod
COPY backend/ ./

# Prvo testiraj osnove, pa pokušaj setup
CMD ["sh", "-c", "echo '🚀 Starting application...' && npm run db:check && echo '---' && npm run db:simple && echo '---' && npm run db:setup && echo '🎉 Starting server...' && npm start"]

EXPOSE 3001
