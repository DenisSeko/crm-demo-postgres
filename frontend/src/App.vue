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
          @login="handleLogin" 
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
import { ref, onMounted, watch } from "vue"
import { useRouter } from "vue-router"

// Components
import AppHeader from "./components/AppHeader.vue"
import HomePage from "./components/HomePage.vue"
import LoginForm from "./components/LoginForm.vue"
import Loader from "./components/Loader.vue"
import Dashboard from "./components/Dashboard.vue"

const router = useRouter()

// State
const user = ref(null)
const showHomepage = ref(true)
const showLoader = ref(false)
const isLoggingIn = ref(false)

// Methods
const goToLogin = () => {
  showHomepage.value = false
  router.push("/?login=true")
}

const goToHome = () => {
  showHomepage.value = true
  router.push("/")
}

const handleLogin = async (loginResponse) => {
  if (loginResponse.success) {
    isLoggingIn.value = true
    showLoader.value = true
    
    try {
      await new Promise(resolve => setTimeout(resolve, 1500))
      
      localStorage.setItem("token", loginResponse.token)
      localStorage.setItem("user", JSON.stringify(loginResponse.user))
      user.value = loginResponse.user
      
      goToHome()
    } finally {
      isLoggingIn.value = false
      showLoader.value = false
    }
  }
}

const logout = () => {
  localStorage.removeItem("token")
  localStorage.removeItem("user")
  user.value = null
  goToHome()
}

// Watchers & Lifecycle
watch(() => router.currentRoute.value.query, (newQuery) => {
  showHomepage.value = newQuery.login !== "true"
}, { immediate: true })

onMounted(() => {
  const savedUser = localStorage.getItem("user")
  const savedToken = localStorage.getItem("token")
  
  if (savedUser && savedToken) {
    user.value = JSON.parse(savedUser)
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
