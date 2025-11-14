import { createRouter, createWebHistory } from 'vue-router'
import { authHelper } from '../services/api'

const routes = [
  {
    path: '/',
    name: 'Home',
    component: () => import('../components/HomePage.vue')
  },
  {
    path: '/dashboard',
    name: 'Dashboard',
    component: () => import('../components/Dashboard.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/login',
    name: 'Login',
    component: () => import('../components/AuthManager.vue')
  },
  {
    path: '/register',
    name: 'Register',
    component: () => import('../components/AuthManager.vue')
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

// Globalni navigation guard
router.beforeEach((to, from, next) => {
  console.log('🛡️ Route guard checking:', to.name)
  
  const isAuthenticated = authHelper.isAuthenticated()
  console.log('🔐 Auth status:', isAuthenticated)
  
  // Ako ruta zahtijeva autentifikaciju i korisnik nije prijavljen
  if (to.meta.requiresAuth && !isAuthenticated) {
    console.log('🚫 Access denied, redirecting to login')
    next({ path: '/', query: { auth: 'login', redirect: to.fullPath } })
  } else {
    next() // Nastavi normalno
  }
})

export default router