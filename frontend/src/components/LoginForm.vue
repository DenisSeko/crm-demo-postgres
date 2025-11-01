<template>
  <div class="max-w-md mx-auto mt-20 p-6 bg-white rounded-lg shadow-md">
    <h2 class="text-2xl font-bold mb-6 text-center">Prijava</h2>
    <form @submit.prevent="handleLogin" class="space-y-4">
      <div>
        <label class="block text-sm font-medium text-gray-700">Email</label>
        <input 
          v-model="loginData.email" 
          type="email"
          class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          required
          @input="clearError"
        >
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700">Lozinka</label>
        <input 
          v-model="loginData.password" 
          type="password"
          class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          required
          @input="clearError"
        >
      </div>
      
      <!-- Error Display -->
      <div v-if="errorMessage" class="p-3 bg-red-50 border border-red-200 rounded-md">
        <p class="text-red-700 text-sm font-medium">❌ {{ errorMessage }}</p>
        <button 
          v-if="showRetryButton"
          @click="handleLogin"
          class="mt-2 text-red-600 underline text-xs"
        >
          Pokušaj ponovo
        </button>
      </div>
      
      <!-- Success Message -->
      <div v-if="successMessage" class="p-3 bg-green-50 border border-green-200 rounded-md">
        <p class="text-green-700 text-sm font-medium">✅ {{ successMessage }}</p>
      </div>

      <button 
        type="submit"
        class="w-full bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 flex items-center justify-center disabled:bg-gray-400 disabled:cursor-not-allowed"
        :disabled="isLoggingIn"
      >
        <span v-if="isLoggingIn" class="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></span>
        {{ isLoggingIn ? "Prijavljujem..." : "Prijavi se" }}
      </button>
    </form>
    
    <!-- Demo Info -->
    <div class="mt-4 p-3 bg-yellow-50 rounded-md text-sm">
      <strong>Demo pristup:</strong><br>
      Email: demo@demo.com<br>
      Lozinka: demo123
    </div>

    <!-- Connection Status -->
    <div class="mt-4 p-3 bg-blue-50 rounded-md text-sm">
      <strong>Status veze:</strong><br>
      <span :class="connectionStatus.class">●</span> {{ connectionStatus.text }}
    </div>

    <!-- Debug Info -->
    <div v-if="showDebugInfo" class="mt-4 p-3 bg-gray-100 rounded-md text-xs">
      <h4 class="font-bold mb-2">🔍 Debug Info:</h4>
      <pre class="whitespace-pre-wrap">{{ debugInfo }}</pre>
      <button 
        @click="testConnection" 
        class="mt-2 bg-gray-500 text-white px-2 py-1 rounded text-xs"
      >
        Testiraj vezu
      </button>
    </div>

    <div class="mt-4 text-center">
      <a 
        href="#" 
        @click.prevent="goHome" 
        class="text-blue-600 hover:text-blue-800 text-sm"
      >
        ← Povratak na početnu
      </a>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from "vue"
import { useRoute, useRouter } from "vue-router"
import { authAPI, healthAPI } from "@/services/api"

const route = useRoute()
const router = useRouter()

const emit = defineEmits(["login-success", "go-home"])

const isLoggingIn = ref(false)
const errorMessage = ref("")
const successMessage = ref("")
const debugInfo = ref("")
const connectionStatus = ref({ text: "Provjeravam...", class: "text-yellow-500" })
const showRetryButton = ref(false)

// Development flags
const isDevelopment = computed(() => 
  window.location.hostname === 'localhost' || 
  window.location.hostname.includes('vercel.app')
)

const showDebugInfo = computed(() => 
  isDevelopment.value || route.query.debug === 'true'
)

const loginData = reactive({
  email: "demo@demo.com",
  password: "demo123"
})

// Auto-detect login mode from URL
const isLoginMode = computed(() => 
  route.query.login === 'true' || 
  window.location.search.includes('login=true')
)

const clearError = () => {
  errorMessage.value = ""
  successMessage.value = ""
  showRetryButton.value = false
}

const goHome = () => {
  if (isLoginMode.value) {
    // Remove login parameter and go to home
    const newUrl = window.location.origin + window.location.pathname
    window.location.href = newUrl
  } else {
    emit('go-home')
  }
}

// Test backend connection
const testConnection = async () => {
  console.log('🔗 Testing backend connection...')
  connectionStatus.value = { text: "Testiram vezu...", class: "text-yellow-500" }
  
  try {
    const health = await healthAPI.check()
    console.log('✅ Backend health:', health)
    connectionStatus.value = { 
      text: `✅ Backend connected (${health.environment})`, 
      class: "text-green-500" 
    }
    debugInfo.value = { ...debugInfo.value, healthCheck: health }
  } catch (error) {
    console.error('❌ Backend connection failed:', error)
    connectionStatus.value = { 
      text: "❌ Backend not reachable", 
      class: "text-red-500" 
    }
  }
}

const handleLogin = async () => {
  isLoggingIn.value = true
  errorMessage.value = ""
  successMessage.value = ""
  showRetryButton.value = false
  
  console.group('🔐 LOGIN PROCESS')
  console.log('📍 URL Analysis:')
  console.log('  - Full URL:', window.location.href)
  console.log('  - Has login param:', isLoginMode.value)
  console.log('  - Frontend URL:', window.location.origin)
  console.log('  - Expected backend: https://crm-staging-app.up.railway.app')
  
  console.log('🔄 Starting login process...')
  console.log('📧 Email:', loginData.email)
  console.log('🔑 Password:', '•'.repeat(loginData.password.length))
  console.log('🌐 Environment:', isDevelopment.value ? 'Development' : 'Production')
  
  try {
    // Step 0: Test connection first
    await testConnection()
    
    // Step 1: Artificial delay za UX
    console.log('⏳ Adding artificial delay...')
    await new Promise(resolve => setTimeout(resolve, 500))
    
    // Step 2: API Call
    console.log('📡 Calling authAPI.login...')
    
    const startTime = Date.now()
    const response = await authAPI.login(loginData.email, loginData.password)
    const endTime = Date.now()
    
    console.log('✅ Login API successful!')
    console.log('⏱️ Response time:', endTime - startTime + 'ms')
    console.log('📦 Response data:', response)
    
    // Step 3: Save to localStorage
    console.log('💾 Saving to localStorage...')
    localStorage.setItem('token', response.token)
    localStorage.setItem('user', JSON.stringify(response.user))
    
    // Verify storage
    const storedToken = localStorage.getItem('token')
    const storedUser = localStorage.getItem('user')
    console.log('🔍 Storage verification - Token:', !!storedToken, 'User:', !!storedUser)
    
    // Step 4: Success handling
    successMessage.value = "Uspješno prijavljen! Preusmjeravam..."
    debugInfo.value = {
      status: 'success',
      timestamp: new Date().toISOString(),
      url: window.location.href,
      response: response,
      storage: {
        token: !!storedToken,
        user: !!storedUser
      }
    }
    
    console.log('🎉 Login process completed successfully!')
    console.groupEnd()
    
    // Step 5: Redirect based on URL mode
    setTimeout(() => {
      if (isLoginMode.value) {
        // Redirect to dashboard when coming from ?login=true
        console.log('🔄 Redirecting to dashboard...')
        window.location.href = window.location.origin + '/dashboard'
      } else {
        // Emit event for SPA navigation
        emit("login-success", response)
      }
    }, 1000)
    
  } catch (error) {
    console.error('❌ LOGIN FAILED:')
    console.error('💥 Error object:', error)
    console.error('📊 Response data:', error.response?.data)
    console.error('🔢 Status code:', error.response?.status)
    console.error('📝 Error message:', error.message)
    console.groupEnd()
    
    // Detailed error handling
    const errorDetails = {
      timestamp: new Date().toISOString(),
      url: window.location.href,
      status: error.response?.status,
      data: error.response?.data,
      message: error.message,
      backendUrl: 'https://crm-staging-app.up.railway.app'
    }
    
    debugInfo.value = errorDetails
    showRetryButton.value = true
    
    // User-friendly error messages
    if (error.response?.status === 401) {
      errorMessage.value = "Pogrešan email ili lozinka. Pokušajte ponovo."
    } else if (error.response?.status === 404) {
      errorMessage.value = "Server nije dostupan. Provjerite backend URL."
    } else if (error.response?.status === 500) {
      errorMessage.value = "Server greška. Pokušajte kasnije."
    } else if (error.code === 'NETWORK_ERROR' || error.message.includes('Network')) {
      errorMessage.value = "Problem s mrežom. Provjerite internet vezu."
    } else if (error.message.includes('CORS')) {
      errorMessage.value = "CORS greška - backend nije konfigurisan za ovaj frontend."
    } else {
      errorMessage.value = error.response?.data?.error || 
                          error.response?.data?.message || 
                          "Došlo je do greške pri prijavi. Pokušajte ponovo."
    }
  } finally {
    console.log('🏁 Login process finished')
    isLoggingIn.value = false
  }
}

// Auto-clear messages after 5 seconds
const clearMessages = () => {
  setTimeout(() => {
    errorMessage.value = ""
    successMessage.value = ""
  }, 5000)
}

// On component mount
onMounted(() => {
  console.log('🚀 Login component mounted')
  console.log('📋 Route query:', route.query)
  console.log('🔍 Login mode detected:', isLoginMode.value)
  
  // Auto-test connection on mount
  testConnection()
  
  // If in login mode, focus on the form
  if (isLoginMode.value) {
    console.log('🎯 Login mode active - auto-focus on email field')
    setTimeout(() => {
      const emailInput = document.querySelector('input[type="email"]')
      if (emailInput) emailInput.focus()
    }, 100)
  }
})
</script>

<style scoped>
/* Additional styles for better UX */
.fade-enter-active, .fade-leave-active {
  transition: opacity 0.5s ease;
}
.fade-enter-from, .fade-leave-to {
  opacity: 0;
}
</style>