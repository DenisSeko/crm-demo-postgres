<template>
  <div class="min-h-screen bg-gray-50">
    <!-- Loader -->
    <Loader v-if="showLoader" />
    
    <!-- Header -->
    <AppHeader 
      :user="user" 
      @go-home="goToHome" 
      @logout="logout" 
    />

    <!-- Main Content -->
    <transition name="fade">
      <div v-if="!user && !showLoader">
        <HomePage 
          v-if="showHomepage" 
          @go-to-login="goToLogin" 
        />
        <LoginForm 
          v-else 
          :is-logging-in="isLoggingIn" 
          @login="login" 
          @go-home="goToHome" 
        />
      </div>
    </transition>

    <!-- Dashboard -->
    <transition name="fade">
      <Dashboard v-if="user && !showLoader" />
    </transition>
  </div>
</template>

<script setup>
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'

// Components
import AppHeader from './components/AppHeader.vue'
import HomePage from './components/HomePage.vue'
import LoginForm from './components/LoginForm.vue'
import Loader from './components/Loader.vue'
import Dashboard from './components/Dashboard.vue'

const router = useRouter()

// State
const user = ref(null)
const showHomepage = ref(true)
const showLoader = ref(false)
const isLoggingIn = ref(false)

// Methods
const goToLogin = () => {
  showHomepage.value = false
  router.push('/?login=true')
}

const goToHome = () => {
  showHomepage.value = true
  router.push('/')
}

const login = async (loginData) => {
  isLoggingIn.value = true
  
  try {
    // Button spinner delay
    await new Promise(resolve => setTimeout(resolve, 500))
    
    const response = await axios.post('/api/login', loginData)
    const { token, user: userData } = response.data
    
    // Show main loader
    showLoader.value = true
    
    // Simulate data loading
    await new Promise(resolve => setTimeout(resolve, 1500))
    
    localStorage.setItem('token', token)
    localStorage.setItem('user', JSON.stringify(userData))
    user.value = userData
    axios.defaults.headers.common['Authorization'] = `Bearer ${token}`
    
    goToHome()
    
  } catch (error) {
    console.error('Login failed:', error.response?.data || error.message)
    alert('Pogrešni podaci za prijavu')
  } finally {
    isLoggingIn.value = false
    showLoader.value = false
  }
}

const logout = () => {
  localStorage.removeItem('token')
  localStorage.removeItem('user')
  user.value = null
  delete axios.defaults.headers.common['Authorization']
  goToHome()
}

// Watchers & Lifecycle
watch(() => router.currentRoute.value.query, (newQuery) => {
  showHomepage.value = newQuery.login !== 'true'
}, { immediate: true })

onMounted(() => {
  // Check for saved user session
  const savedUser = localStorage.getItem('user')
  const savedToken = localStorage.getItem('token')
  
  if (savedUser && savedToken) {
    user.value = JSON.parse(savedUser)
    axios.defaults.headers.common['Authorization'] = `Bearer ${savedToken}`
  }
})
</script>

<style>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.5s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
