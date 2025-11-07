import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [vue()],
  
  // Development server config
  server: {
    port: 5173,
    host: true, // Dodaj ovo za Upsun
    proxy: {
      '/api': {
        target: 'http://localhost:3001',
        changeOrigin: true,
        secure: false
      }
    }
  },
  
  // Production build config - DODAJ OVO
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    emptyOutDir: true
  },
  
  // Preview server config - OVO JE KLJUČNO ZA UPSUN
  preview: {
    port: 3000,
    host: true, // Ovo omogućava da server sluša na 0.0.0.0
    allowedHosts: true // Dopusti sve hostove
  }
})