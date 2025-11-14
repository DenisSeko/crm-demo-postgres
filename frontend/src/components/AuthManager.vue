<template>
  <div>
    <Login 
      v-if="currentView === 'login'"
      :is-logging-in="isLoading"
      @login="handleLogin"
      @show-register="switchToRegister"
      @go-home="goToHome"
      ref="loginRef"
    />
    
    <Registration 
      v-else
      :is-registering="isLoading"
      @show-login="switchToLogin"
      @go-home="goToHome"
      @registered="handleRegistered"
    />
  </div>
</template>

<script setup>
import { ref, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import Login from './LoginForm.vue'
import Registration from './Registration.vue'

const router = useRouter()
const route = useRoute()

// Props
const props = defineProps({
  initialView: {
    type: String,
    default: 'login',
    validator: (value) => ['login', 'register'].includes(value)
  }
})

const emit = defineEmits(['success', 'go-home'])

// State
const currentView = ref(props.initialView)
const isLoading = ref(false)
const loginRef = ref(null)

console.log('🚀 AuthManager mounted sa initialView:', props.initialView)
console.log('📍 Trenutna ruta:', route.path)

// Methods
const switchToLogin = () => {
  console.log('🔄 Prebacujem na login...')
  currentView.value = 'login'
  router.push('/login')
}

const switchToRegister = () => {
  console.log('🔄 Prebacujem na register...')
  currentView.value = 'register'
  router.push('/register')
}

const goToHome = () => {
  router.push('/')
}

const handleLogin = async (loginData) => {
  isLoading.value = true
  
  try {
    console.log('🔄 AuthManager: Primljeni login podaci:', loginData)
    
    // Dodaj loading delay za bolji UX
    await new Promise(resolve => setTimeout(resolve, 800))
    
    console.log('✅ AuthManager: Prosljeđujem podatke parent komponenti')
    
    // Proslijedi podatke parent komponenti (App.vue)
    emit('success', loginData)
    
  } catch (error) {
    console.error('❌ AuthManager: Greška pri prijavi:', error)
    
    // Proslijedi grešku LoginForm komponenti
    if (loginRef.value && loginRef.value.showError) {
      loginRef.value.showError(
        error.message || 'Došlo je do greške pri prijavi. Pokušajte ponovno.'
      )
    } else {
      console.error('❌ LoginRef nije dostupan za prikaz greške')
    }
    
  } finally {
    isLoading.value = false
  }
}

const handleRegistered = async (userData) => {
  console.log('✅ AuthManager: User registered:', userData)
  
  // Dodaj mali delay prije prebacivanja na login
  isLoading.value = true
  try {
    await new Promise(resolve => setTimeout(resolve, 1000))
    switchToLogin()
  } finally {
    isLoading.value = false
  }
}

// Force view based on route - NUCLEAR OPTION za sigurnost
const forceViewBasedOnRoute = () => {
  console.log('🔧 Force view check:')
  console.log('   - Route path:', route.path)
  console.log('   - Current view:', currentView.value)
  
  if (route.path === '/register') {
    if (currentView.value !== 'register') {
      console.log('💥 FORCE: Setting to register view')
      currentView.value = 'register'
    }
  } else if (route.path === '/login') {
    if (currentView.value !== 'login') {
      console.log('💥 FORCE: Setting to login view')
      currentView.value = 'login'
    }
  } else {
    console.log('ℹ️  Unknown route, using prop value:', props.initialView)
    currentView.value = props.initialView
  }
}

// Watchers
watch(
  () => props.initialView,
  (newView) => {
    console.log('🔄 Props initialView promijenjen:', newView)
    currentView.value = newView
  }
)

watch(
  () => route.path,
  (newPath, oldPath) => {
    console.log('🔄 Ruta promijenjena:', oldPath, '→', newPath)
    forceViewBasedOnRoute()
  }
)

// Lifecycle
onMounted(() => {
  console.log('🎯 AuthManager mounted - inicijalni setup')
  forceViewBasedOnRoute()
  
  // Dodatna provjera nakon mounta
  setTimeout(() => {
    console.log('🔍 Post-mount check:')
    console.log('   - Final route:', route.path)
    console.log('   - Final view:', currentView.value)
    console.log('   - View matches route:', 
      (route.path === '/register' && currentView.value === 'register') ||
      (route.path === '/login' && currentView.value === 'login')
    )
  }, 100)
})

// Expose methods ako su potrebne
defineExpose({
  switchToLogin,
  switchToRegister,
  setView: (view) => {
    if (['login', 'register'].includes(view)) {
      currentView.value = view
    }
  }
})
</script>

<style scoped>
/* Smooth transitions za cijelu komponentu */
* {
  transition: all 0.3s ease-in-out;
}
</style>