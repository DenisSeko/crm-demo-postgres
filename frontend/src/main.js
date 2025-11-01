// EMERGENCY VERSION CHECK
console.log('🚨 EMERGENCY VERSION CHECK')
console.log('🕒 Deployment Time:', new Date().toISOString())
console.log('🔗 Expected API:', 'https://crm-staging-app.up.railway.app')

// Force API test immediately
fetch('https://crm-staging-app.up.railway.app/api/health')
  .then(r => r.json())
  .then(data => console.log('✅ Backend is live:', data))
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import { createRouter, createWebHistory } from 'vue-router'
import App from './App.vue'

// Kreiraj router
const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/',
      name: 'Home',
      component: App
    }
  ]
})

const app = createApp(App)
app.use(createPinia())
app.use(router)
app.mount('#app')
