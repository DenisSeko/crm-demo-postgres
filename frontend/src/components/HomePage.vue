<template>
  <div class="min-h-screen bg-gradient-to-br from-blue-50 via-white to-indigo-100 flex items-center justify-center p-4">
    <div class="max-w-6xl mx-auto w-full">
      <!-- Hero Section -->
      <div class="text-center mb-16">
        <div class="mb-6">
          <div class="inline-flex items-center justify-center w-20 h-20 bg-blue-600 rounded-2xl shadow-lg mb-4">
            <span class="text-3xl text-white">🚀</span>
          </div>
        </div>
        <h1 class="text-4xl md:text-6xl font-bold text-gray-900 mb-6">
          Moderni <span class="text-blue-600">CRM</span> Sustav
        </h1>
        <p class="text-xl md:text-2xl text-gray-600 max-w-3xl mx-auto leading-relaxed">
          Upravljajte svojim klijentima, bilješkama i poslovanjem na jednom mjestu
        </p>
      </div>

      <!-- Features Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-16">
        <div class="bg-white p-6 rounded-xl shadow-sm border border-gray-100 hover:shadow-md transition-all duration-300 transform hover:-translate-y-1">
          <div class="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center mb-4">
            <span class="text-xl text-blue-600">👥</span>
          </div>
          <h3 class="text-lg font-semibold text-gray-800 mb-2">Upravljanje Klijentima</h3>
          <p class="text-gray-600 text-sm leading-relaxed">
            Organizirajte sve vaše klijente, kontakt podatke i povijest suradnje na jednom mjestu
          </p>
        </div>
        
        <div class="bg-white p-6 rounded-xl shadow-sm border border-gray-100 hover:shadow-md transition-all duration-300 transform hover:-translate-y-1">
          <div class="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center mb-4">
            <span class="text-xl text-green-600">📝</span>
          </div>
          <h3 class="text-lg font-semibold text-gray-800 mb-2">Bilješke i Aktivnosti</h3>
          <p class="text-gray-600 text-sm leading-relaxed">
            Pratite sve razgovore, sastanke i važne događaje s detaljnim bilješkama
          </p>
        </div>
        
        <div class="bg-white p-6 rounded-xl shadow-sm border border-gray-100 hover:shadow-md transition-all duration-300 transform hover:-translate-y-1">
          <div class="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mb-4">
            <span class="text-xl text-purple-600">📊</span>
          </div>
          <h3 class="text-lg font-semibold text-gray-800 mb-2">Analitika i Izvještaji</h3>
          <p class="text-gray-600 text-sm leading-relaxed">
            Dobijte uvid u performance kroz detaljne statistike i grafikone
          </p>
        </div>
        
        <div class="bg-white p-6 rounded-xl shadow-sm border border-gray-100 hover:shadow-md transition-all duration-300 transform hover:-translate-y-1">
          <div class="w-12 h-12 bg-orange-100 rounded-lg flex items-center justify-center mb-4">
            <span class="text-xl text-orange-600">🔒</span>
          </div>
          <h3 class="text-lg font-semibold text-gray-800 mb-2">Sigurnost Podataka</h3>
          <p class="text-gray-600 text-sm leading-relaxed">
            JWT autentikacija i sigurna PostgreSQL baza podataka za zaštitu vaših podataka
          </p>
        </div>
      </div>

      <!-- CTA Section -->
      <div class="text-center mb-16">
        <div class="bg-white rounded-2xl shadow-sm border border-gray-100 p-8 max-w-2xl mx-auto">
          <h2 class="text-2xl md:text-3xl font-bold text-gray-800 mb-4">
            Spremni za početak?
          </h2>
          <p class="text-gray-600 mb-8 max-w-xl mx-auto">
            Pridružite se tisućama zadovoljnih korisnika koji već upravljaju svojim poslovanjem putem našeg CRM sustava
          </p>
          
          <div class="flex flex-col sm:flex-row gap-4 justify-center items-center">
            <button 
              @click="goToLogin"
              class="group bg-blue-600 text-white px-8 py-4 rounded-xl hover:bg-blue-700 transition-all duration-200 font-semibold text-lg shadow-lg hover:shadow-xl transform hover:-translate-y-0.5 flex items-center gap-3 min-w-[200px] justify-center"
            >
              <span class="group-hover:scale-110 transition-transform">🔐</span>
              Prijavi se
            </button>
            
            <button 
              @click="goToRegister"
              class="group bg-gradient-to-r from-green-500 to-emerald-600 text-white px-8 py-4 rounded-xl hover:from-green-600 hover:to-emerald-700 transition-all duration-200 font-semibold text-lg shadow-lg hover:shadow-xl transform hover:-translate-y-0.5 flex items-center gap-3 min-w-[200px] justify-center"
            >
              <span class="group-hover:scale-110 transition-transform">👤</span>
              Registriraj se
            </button>
          </div>
        </div>
      </div>

      <!-- Demo Access Section -->
      <div class="bg-gradient-to-r from-yellow-50 to-amber-50 rounded-2xl border border-yellow-200 p-8 max-w-4xl mx-auto">
        <div class="text-center mb-6">
          <div class="inline-flex items-center justify-center w-16 h-16 bg-yellow-100 rounded-full mb-4">
            <span class="text-2xl text-yellow-600">🎯</span>
          </div>
          <h3 class="text-2xl font-bold text-yellow-800 mb-2">Želite prvo isprobati?</h3>
          <p class="text-yellow-700">
            Koristite demo račune za testiranje svih funkcionalnosti. Svi korisnici koriste lozinku: 
            <span class="font-mono font-bold bg-yellow-200 px-2 py-1 rounded">password123</span>
          </p>
        </div>
        
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <div v-for="demoUser in demoUsers" :key="demoUser.email" 
            class="bg-white rounded-lg p-4 border border-yellow-100 hover:border-yellow-300 transition-colors duration-200">
            <div class="flex items-center justify-between mb-2">
              <span class="font-semibold text-gray-800 text-sm">{{ demoUser.name }}</span>
              <span class="px-2 py-1 text-xs rounded-full" :class="demoUser.role === 'admin' ? 'bg-purple-100 text-purple-800' : 'bg-blue-100 text-blue-800'">
                {{ demoUser.role }}
              </span>
            </div>
            <div class="text-xs text-gray-600 font-mono mb-3">{{ demoUser.email }}</div>
            <button 
              @click="useDemoAccount(demoUser)"
              class="w-full bg-yellow-500 text-white py-2 px-3 rounded-lg hover:bg-yellow-600 transition-colors duration-200 text-sm font-medium flex items-center justify-center gap-2"
            >
              <span>⚡</span>
              Koristi račun
            </button>
          </div>
        </div>
      </div>

      <!-- Tech Stack -->
      <div class="text-center mt-16">
        <p class="text-gray-500 text-sm mb-4">Powered by modern tech stack</p>
        <div class="flex flex-wrap justify-center gap-6 opacity-75">
          <div class="flex items-center gap-2 text-gray-600">
            <span>⚡</span>
            <span class="font-mono text-sm">Vue 3</span>
          </div>
          <div class="flex items-center gap-2 text-gray-600">
            <span>🔷</span>
            <span class="font-mono text-sm">Node.js</span>
          </div>
          <div class="flex items-center gap-2 text-gray-600">
            <span>🐘</span>
            <span class="font-mono text-sm">PostgreSQL</span>
          </div>
          <div class="flex items-center gap-2 text-gray-600">
            <span>🔐</span>
            <span class="font-mono text-sm">JWT Auth</span>
          </div>
          <div class="flex items-center gap-2 text-gray-600">
            <span>🎨</span>
            <span class="font-mono text-sm">Tailwind CSS</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'

const router = useRouter()
const emit = defineEmits(['go-to-login', 'go-to-register', 'use-demo-account'])

const demoUsers = ref([
  {
    name: 'Admin',
    email: 'admin@crm.com',
    password: 'password123',
    role: 'admin'
  },
  {
    name: 'Ivan Horvat',
    email: 'ivan.horvat@primjer.hr',
    password: 'password123',
    role: 'user'
  },
  {
    name: 'Ana Kovač',
    email: 'ana.kovac@primjer.hr', 
    password: 'password123',
    role: 'user'
  },
  {
    name: 'Marko Petrov',
    email: 'marko.petrov@primjer.hr',
    password: 'password123',
    role: 'user'
  }
])

const goToLogin = () => {
  console.log('🔄 Redirect na login...')
  router.push('/login')
}

const goToRegister = () => {
  console.log('🔄 Redirect na registraciju...')
  router.push('/register')
}

const useDemoAccount = (demoUser) => {
  console.log(`🔐 Koristim demo račun: ${demoUser.email}`)
  
  // Emit event parent komponenti (App.vue) ako je potrebno
  emit('use-demo-account', demoUser)
  
  // Direktan redirect na login sa prefilled podacima
  router.push({
    path: '/login',
    query: { 
      email: demoUser.email,
      password: demoUser.password,
      demo: 'true'
    }
  })
}
</script>

<style scoped>
/* Custom animations */
.hover-lift:hover {
  transform: translateY(-2px);
  transition: transform 0.2s ease;
}

/* Smooth transitions for all interactive elements */
button, .demo-card {
  transition: all 0.3s ease;
}
</style>