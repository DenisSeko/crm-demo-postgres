// vite.config.js - PRIVREMENO promijeni
import { defineConfig } from "vite"
import vue from "@vitejs/plugin-vue"

export default defineConfig({
  plugins: [vue()],
  base: "/",
  build: {
    outDir: "dist",
    emptyOutDir: true
  },
  // UKLONI server.proxy sekciju za sada
  // Netlify ne koristi Vite dev server u produkciji
})
