FROM node:18-alpine

WORKDIR /app

# Kopiraj package fajlove
COPY backend/package*.json ./

# Instaliraj zavisnosti
RUN npm install --production

# Kopiraj backend kod
COPY backend/ ./

# Kopiraj schema.sql na specifičnu lokaciju
COPY database/schema.sql ./database/schema.sql

# Pokreni database setup pa server
CMD ["sh", "-c", "echo '🚀 Starting application...' && npm run db:setup && echo '🎉 Starting server...' && npm start"]

EXPOSE 3001
