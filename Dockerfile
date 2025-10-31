FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --production --silent

# Copy all source files
COPY . ./

# ✅ ULTRA-FAST START: Use start.js which launches immediately
CMD ["node", "start.js"]

EXPOSE 3001
