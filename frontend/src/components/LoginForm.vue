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

    <!-- Debug Info (samo u developmentu) -->
    <div v-if="debugInfo && isDevelopment" class="mt-4 p-3 bg-gray-100 rounded-md text-xs">
      <h4 class="font-bold mb-2">🔍 Debug Info:</h4>
      <pre class="whitespace-pre-wrap">{{ debugInfo }}</pre>
    </div>

    <div class="mt-4 text-center">
      <a 
        href="#" 
        @click.prevent="$emit('go-home')" 
        class="text-blue-600 hover:text-blue-800 text-sm"
      >
        ← Povratak na početnu
      </a>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed } from "vue"
import { authAPI } from "@/services/api"

const emit = defineEmits(["login-success", "go-home"])

const isLoggingIn = ref(false)
const errorMessage = ref("")
const successMessage = ref("")
const debugInfo = ref("")

// Development flag
const isDevelopment = computed(() => 
  window.location.hostname === 'localhost' || 
  window.location.hostname.includes('vercel.app')
)

const loginData = reactive({
  email: "demo@demo.com",
  password: "demo123"
})

const clearError = () => {
  errorMessage.value = ""
  successMessage.value = ""
}

const handleLogin = async () => {
  isLoggingIn.value = true
  errorMessage.value = ""
  successMessage.value = ""
  debugInfo.value = ""
  
  console.group('🔐 LOGIN PROCESS')
  console.log('🔄 Starting login process...')
  console.log('📧 Email:', loginData.email)
  console.log('🔑 Password:', '•'.repeat(loginData.password.length))
  console.log('🌐 Environment:', isDevelopment.value ? 'Development' : 'Production')
  
  try {
    // Step 1: Artificial delay za UX
    console.log('⏳ Adding artificial delay...')
    await new Promise(resolve => setTimeout(resolve, 500))
    
    // Step 2: API Call
    console.log('📡 Calling authAPI.login...')
    console.log('🔗 API URL: Expected to be https://crm-staging-app.up.railway.app/api/login')
    
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
      response: response,
      storage: {
        token: !!storedToken,
        user: !!storedUser
      }
    }
    
    console.log('🎉 Login process completed successfully!')
    console.groupEnd()
    
    // Step 5: Emit event with small delay to show success message
    setTimeout(() => {
      emit("login-success", response)
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
      status: error.response?.status,
      data: error.response?.data,
      message: error.message
    }
    
    debugInfo.value = errorDetails
    
    // User-friendly error messages
    if (error.response?.status === 401) {
      errorMessage.value = "Pogrešan email ili lozinka. Pokušajte ponovo."
    } else if (error.response?.status === 404) {
      errorMessage.value = "Server nije dostupan. Pokušajte kasnije."
    } else if (error.response?.status === 500) {
      errorMessage.value = "Server greška. Pokušajte kasnije."
    } else if (error.code === 'NETWORK_ERROR' || error.message.includes('Network')) {
      errorMessage.value = "Problem s mrežom. Provjerite internet vezu."
    } else {
      errorMessage.value = error.response?.data?.error || 
                          error.response?.data?.message || 
                          "Došlo je do greške pri prijavi. Pokušajte ponovo."
    }
    
    // Don't show alert if we're showing error message in UI
    // alert("Pogrešni podaci za prijavu: " + errorMessage.value)
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

// Test API connection on component mount (development only)
import { onMounted } from 'vue'
onMounted(() => {
  if (isDevelopment.value) {
    console.log('🚀 Login component mounted')
    console.log('📍 Current URL:', window.location.href)
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