import { defineConfig } from "vite"
import vue from "@vitejs/plugin-vue"

export default defineConfig({
  plugins: [vue()],
  base: "/",
  build: {
    outDir: "dist",
    emptyOutDir: true
  },
  server: {
    proxy: {
      "/api": {
        target: "https://crm-staging-app.up.railway.app",
        changeOrigin: true,
        secure: false
      }
    }
  }
})
