<template>
  <div class="min-h-screen bg-gray-50">
    <!-- Global Loader - za login → dashboard prijelaz -->
    <Loader 
      v-if="showGlobalLoader" 
      :message="loaderMessage"
      :sub-message="loaderSubMessage"
    />
    
    <!-- Header -->
    <AppHeader 
      :user="user" 
      @go-home="goToHome" 
      @logout="handleLogout" 
    />

    <!-- Main Content -->
    <main class="container mx-auto px-4 py-8">
      <transition name="page-fade" mode="out-in">
        <!-- Homepage -->
        <HomePage 
          v-if="showHomepage && !user && !showGlobalLoader" 
          @go-to-login="goToLogin"
          @go-to-register="goToRegister" 
          key="homepage"
        />
        
        <!-- Auth Manager -->
        <AuthManager 
          v-else-if="!user && !showGlobalLoader" 
          :initial-view="authView"
          @success="handleAuthSuccess"
          @go-home="goToHome"
          key="auth"
        />

        <!-- Dashboard -->
        <Dashboard 
          v-else-if="user && !showGlobalLoader" 
          :user="user"
          @logout="handleLogout" 
          key="dashboard"
        />
      </transition>
    </main>

    <!-- Globalna notifikacija -->
    <div v-if="globalMessage" class="fixed top-4 right-4 z-50 max-w-sm">
      <div :class="[
        'p-4 rounded-lg shadow-lg border transform transition-all duration-300',
        globalMessageType === 'error' 
          ? 'bg-red-50 border-red-200 text-red-800' 
          : 'bg-green-50 border-green-200 text-green-800'
      ]">
        <div class="flex items-center justify-between">
          <div class="flex items-center">
            <span class="text-lg mr-2">
              {{ globalMessageType === 'error' ? '❌' : '✅' }}
            </span>
            <span class="font-medium">{{ globalMessage }}</span>
          </div>
          <button 
            @click="clearGlobalMessage" 
            class="ml-4 text-gray-500 hover:text-gray-700"
          >
            ✕
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import api, { authHelper } from './services/api'

// Components
import AppHeader from './components/AppHeader.vue'
import HomePage from './components/HomePage.vue'
import AuthManager from './components/AuthManager.vue'
import Loader from './components/Loader.vue'
import Dashboard from './components/Dashboard.vue'

const router = useRouter()
const route = useRoute()

// State
const user = ref(null)
const showHomepage = ref(true)
const showGlobalLoader = ref(false)
const authView = ref('login')
const globalMessage = ref('')
const globalMessageType = ref('success')

// Loader messages
const loaderMessage = ref('Učitavanje...')
const loaderSubMessage = ref('Prijavljujemo vas u sustav')

// Methods
const showGlobalMessage = (message, type = 'success') => {
  globalMessage.value = message
  globalMessageType.value = type
  setTimeout(() => {
    clearGlobalMessage()
  }, 5000)
}

const clearGlobalMessage = () => {
  globalMessage.value = ''
  globalMessageType.value = 'success'
}

const goToLogin = () => {
  showHomepage.value = false
  authView.value = 'login'
  router.push('/login').catch(() => {}) // PROMJENA: Uklonio query parametar
}

const goToRegister = () => {
  showHomepage.value = false
  authView.value = 'register'
  router.push('/register').catch(() => {}) // PROMJENA: Uklonio query parametar
}

const goToHome = () => {
  showHomepage.value = true
  authView.value = 'login'
  router.push('/').catch(() => {})
}

const handleAuthSuccess = async (authData) => {
  console.log('🔄 Auth success handler pokrenut:', authData)
  
  // Postavi loader poruke
  loaderMessage.value = 'Provjeravam podatke...'
  loaderSubMessage.value = 'Autenticiram vaš račun'
  showGlobalLoader.value = true
  
  try {
    // Simuliraj provjeru podataka
    await new Promise(resolve => setTimeout(resolve, 800))
    
    // Koristimo authHelper za spremanje podataka
    authHelper.setAuth(authData.token, authData.user)
    
    // Postavi user stanje
    user.value = authData.user
    console.log('✅ User postavljen u App.vue:', user.value)
    
    // Ažuriraj loader poruke
    loaderMessage.value = 'Uspješno prijavljeni!'
    loaderSubMessage.value = `Dobrodošli, ${authData.user.firstName}!`
    
    // Prikaži poruku uspjeha
    showGlobalMessage(`Dobrodošli, ${authData.user.firstName}!`, 'success')
    
    // Simuliraj loading prije prelaska na dashboard
    await new Promise(resolve => setTimeout(resolve, 1200))
    
    console.log('✅ Auth success završeno, prebacujem na dashboard...')
    
  } catch (error) {
    console.error('Auth success handling error:', error)
    showGlobalMessage('Greška pri prijavi', 'error')
  } finally {
    // Sakrij loader
    showGlobalLoader.value = false
    // Reset poruke
    loaderMessage.value = 'Učitavanje...'
    loaderSubMessage.value = 'Prijavljujemo vas u sustav'
  }
}

const handleLogout = () => {
  authHelper.clearAuth()
  user.value = null
  showGlobalMessage('Uspješno ste se odjavili', 'success')
  console.log('✅ User logged out')
  
  goToHome()
}

// Check authentication status on app start
const checkAuthStatus = () => {
  console.log('🔍 Provjeram auth status...')
  
  if (authHelper.isAuthenticated()) {
    const storedUser = authHelper.getUser()
    user.value = storedUser
    console.log('✅ User restored from localStorage:', user.value)
    showGlobalMessage(`Dobrodošli natrag, ${storedUser.firstName}!`, 'success')
  } else {
    user.value = null
    console.log('ℹ️ Nema validnog auth tokena')
  }
}

// Watchers - PROMJENA: Uklonio query watcher jer sada koristimo direktne rute
watch(
  () => route.path,
  (newPath) => {
    console.log('📍 Route changed:', newPath)
    if (newPath === '/login') {
      showHomepage.value = false
      authView.value = 'login'
    } else if (newPath === '/register') {
      showHomepage.value = false
      authView.value = 'register'
    } else if (newPath === '/') {
      showHomepage.value = true
      authView.value = 'login'
    }
  },
  { immediate: true }
)

// Lifecycle
onMounted(() => {
  console.log('🚀 App.vue mounted')
  checkAuthStatus()
  
  // Listen for storage changes (logout from other tabs)
  window.addEventListener('storage', (event) => {
    if (event.key === 'authToken' && !event.newValue) {
      console.log('🔐 Storage changed - logging out')
      handleLogout()
    }
  })
})

// Cleanup
import { onUnmounted } from 'vue'
onUnmounted(() => {
  window.removeEventListener('storage', handleLogout)
})
</script>

<style scoped>
.page-fade-enter-active,
.page-fade-leave-active {
  transition: opacity 0.4s ease, transform 0.4s ease;
}

.page-fade-enter-from {
  opacity: 0;
  transform: translateY(20px);
}

.page-fade-leave-to {
  opacity: 0;
  transform: translateY(-20px);
}

.container {
  max-width: 1200px;
}
</style>