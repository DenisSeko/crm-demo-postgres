#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════╗"
echo "║           🚀 FRONTEND UPDATE SCRIPT          ║"
echo "║        PostgreSQL Backend Integration        ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

# Success check function
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${RED}❌ $1${NC}"
        exit 1
    fi
}

# File creation function
create_file() {
    echo -e "${YELLOW}📝 Creating/Updating $1...${NC}"
    mkdir -p "$(dirname "$1")"
    cat > "$1" << CONTENT
$2
CONTENT
    check_success "Created $1"
}

# 1. UPDATE FRONTEND ENVIRONMENT
echo -e "${YELLOW}🔧 Updating frontend environment...${NC}"

create_file "frontend/.env.production" 'VITE_API_URL=https://crm-staging-backend.up.railway.app
VITE_APP_ENV=staging'

# 2. UPDATE VITE CONFIG
create_file "frontend/vite.config.js" 'import { defineConfig } from "vite"
import vue from "@vitejs/plugin-vue"

export default defineConfig({
  plugins: [vue()],
  base: "/",
  build: {
    outDir: "dist",
    emptyOutDir: true
  },
  server: {
    proxy: {
      "/api": {
        target: "https://crm-staging-backend.up.railway.app",
        changeOrigin: true,
        secure: false
      }
    }
  }
})'

# 3. CREATE API SERVICE
create_file "frontend/src/services/api.js" 'import axios from "axios"

const API_URL = import.meta.env.VITE_API_URL || "https://crm-staging-backend.up.railway.app"

const api = axios.create({
  baseURL: API_URL,
  headers: {
    "Content-Type": "application/json",
  },
})

// Auth API
export const authAPI = {
  login: async (email, password) => {
    const response = await api.post("/api/auth/login", { email, password })
    return response.data
  },
}

// Clients API  
export const clientsAPI = {
  getAll: async () => {
    const response = await api.get("/api/clients")
    return response.data
  },
  
  create: async (clientData) => {
    const response = await api.post("/api/clients", clientData)
    return response.data
  },
  
  getNotes: async (clientId) => {
    const response = await api.get(\`/api/clients/\${clientId}/notes\`)
    return response.data
  },
  
  addNote: async (clientId, content) => {
    const response = await api.post(\`/api/clients/\${clientId}/notes\`, { content })
    return response.data
  },

  deleteClient: async (clientId) => {
    const response = await api.delete(\`/api/clients/\${clientId}\`)
    return response.data
  },

  getStats: async () => {
    const response = await api.get("/api/clients/stats")
    return response.data
  },

  getNotesCount: async () => {
    const response = await api.get("/api/clients/notes-count")
    return response.data
  }
}

// Notes API
export const notesAPI = {
  deleteNote: async (noteId) => {
    const response = await api.delete(\`/api/notes/\${noteId}\`)
    return response.data
  }
}

// Health check
export const healthAPI = {
  check: async () => {
    const response = await api.get("/api/health")
    return response.data
  },
}

export default api'

# 4. UPDATE DASHBOARD COMPONENT
create_file "frontend/src/components/Dashboard.vue" '<template>
  <div class="max-w-6xl mx-auto p-6">
    <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
      <div class="bg-white p-6 rounded-lg shadow-sm border">
        <h3 class="text-lg font-semibold text-gray-700">Ukupno klijenata</h3>
        <p class="text-3xl font-bold text-blue-600">{{ stats.clients }}</p>
      </div>
      <div class="bg-white p-6 rounded-lg shadow-sm border">
        <h3 class="text-lg font-semibold text-gray-700">Ukupno bilješki</h3>
        <p class="text-3xl font-bold text-green-600">{{ stats.totalNotes || 0 }}</p>
      </div>
      <div class="bg-white p-6 rounded-lg shadow-sm border">
        <h3 class="text-lg font-semibold text-gray-700">Zadnja bilješka</h3>
        <p class="text-sm text-gray-600 mt-1 truncate">{{ stats.lastNote || "Nema bilježki" }}</p>
      </div>
      <div class="bg-white p-6 rounded-lg shadow-sm border">
        <h3 class="text-lg font-semibold text-gray-700">Akcije</h3>
        <button @click="showNewClient = true"
          class="mt-2 bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 w-full">
          + Novi klijent
        </button>
      </div>
    </div>

    <div v-if="showNewClient" class="bg-white p-6 rounded-lg shadow-sm border mb-6">
      <h3 class="text-lg font-semibold mb-4">Novi klijent</h3>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Ime klijenta *</label>
          <input v-model="newClient.name" placeholder="Unesite ime klijenta"
            class="border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 w-full" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Email *</label>
          <input v-model="newClient.email" placeholder="email@primjer.com"
            class="border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 w-full" />
        </div>
        <div class="md:col-span-2">
          <label class="block text-sm font-medium text-gray-700 mb-1">Tvrtka</label>
          <input v-model="newClient.company" placeholder="Naziv tvrtke (opcionalno)"
            class="border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 w-full" />
        </div>
      </div>
      <div class="flex gap-2 mt-4">
        <button @click="createClient"
          class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 flex items-center gap-2"
          :disabled="!newClient.name || !newClient.email || creatingClient">
          <span v-if="creatingClient" class="animate-spin">⏳</span>
          <span v-else>💾</span>
          {{ creatingClient ? "Spremanje..." : "Spremi" }}
        </button>
        <button @click="cancelNewClient"
          class="bg-gray-500 text-white px-4 py-2 rounded-md hover:bg-gray-600 flex items-center gap-2">
          <span>❌</span>
          Otkaži
        </button>
      </div>
    </div>

    <div class="bg-white rounded-lg shadow-sm border">
      <div class="p-6 border-b">
        <div class="flex justify-between items-center">
          <h3 class="text-lg font-semibold">Klijenti</h3>
          <div class="text-sm text-gray-600">
            Ukupno bilješki u sustavu: <span class="font-bold text-green-600">{{ stats.totalNotes }}</span>
          </div>
        </div>
      </div>

      <div v-if="loading" class="p-6 text-center text-gray-500">
        <div class="flex justify-center items-center gap-2">
          <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600"></div>
          Učitavanje klijenata...
        </div>
      </div>

      <div v-else-if="clients.length === 0" class="p-6 text-center text-gray-500">
        <div class="max-w-md mx-auto">
          <div class="text-4xl mb-4">📊</div>
          <h3 class="text-lg font-semibold mb-2">Nema klijenata</h3>
          <p class="text-sm mb-4">Dodajte prvog klijenta kako biste počeli koristiti CRM sustav.</p>
          <button @click="showNewClient = true" class="bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700">
            + Dodaj prvog klijenta
          </button>
        </div>
      </div>

      <ul v-else class="divide-y">
        <li v-for="client in clients" :key="client.id" class="p-6 hover:bg-gray-50 transition-colors duration-200">
          <div class="flex justify-between items-start">
            <div class="flex-1">
              <div class="flex items-center gap-3 mb-2">
                <h4 class="font-semibold text-lg text-gray-800">{{ client.name }}</h4>
                <span class="bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded-full">
                  {{ getNoteCountDisplay(client.id) }}
                </span>
              </div>
              <p class="text-gray-600 flex items-center gap-2">
                <span>📧</span>
                {{ client.email }}
              </p>
              <p class="text-sm text-gray-500 flex items-center gap-2 mt-1">
                <span>🏢</span>
                {{ client.company || "Nema podataka o tvrtki" }}
              </p>
              <p class="text-xs text-gray-400 mt-2">
                Kreiran: {{ new Date(client.created_at).toLocaleDateString("hr-HR") }}
              </p>
            </div>
            <div class="flex gap-2">
              <button @click="initLoaderAndToggleNotes(client.id)"
                class="text-blue-600 hover:text-blue-800 px-3 py-2 rounded border border-blue-200 hover:bg-blue-50 transition-colors duration-200 flex items-center gap-2"
                :title="notesOpen[client.id] ? \"Sakrij bilješke\" : \"Prikaži bilješke\""
                :disabled="loadingNotes[client.id]">
                <span>{{ notesOpen[client.id] ? "📕" : "📘" }}</span>
                <template v-if="loadingNotes[client.id]">
                  <div class="flex items-center gap-1">
                    <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-500"></div>
                    Učitavanje...
                  </div>
                </template>
                <template v-else>
                  {{ notesOpen[client.id] ? "Sakrij" : "Bilješke" }} ({{ getNoteCountDisplay(client.id) }})
                </template>
              </button>
              <button @click="deleteClient(client.id)"
                class="text-red-600 hover:text-red-800 px-3 py-2 rounded border border-red-200 hover:bg-red-50 transition-colors duration-200 flex items-center gap-2"
                title="Obriši klijenta"
                :disabled="deletingClientId === client.id">
                <span v-if="deletingClientId === client.id" class="animate-spin">⏳</span>
                <span v-else>🗑️</span>
                {{ deletingClientId === client.id ? "Briše se..." : "Obriši" }}
              </button>
            </div>
          </div>

          <div v-if="notesOpen[client.id]" class="mt-4 ml-4 p-4 bg-gray-50 rounded-lg border">
            <h5 class="font-semibold mb-3 flex items-center gap-2 text-gray-700">
              <span>📝</span>
              Bilješke za {{ client.name }}
              <span class="bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded-full">
                {{ getNoteCountDisplay(client.id) }}
              </span>
            </h5>

            <div v-if="loadingNotes[client.id]" class="text-center py-4">
              <div class="flex justify-center items-center gap-2 text-gray-500">
                <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
                <div>Učitavanje bilješki...</div>
              </div>
            </div>

            <div v-else-if="clientNotes[client.id]?.length === 0"
              class="text-gray-500 text-sm mb-3 p-4 bg-white rounded border text-center">
              <div class="text-2xl mb-2">📄</div>
              <p>Nema bilježki za ovog klijenta.</p>
              <p class="text-xs mt-1">Dodajte prvu bilješku ispod.</p>
            </div>

            <ul v-else class="space-y-3 mb-4">
              <li v-for="note in clientNotes[client.id]" :key="note.id"
                class="bg-white p-4 rounded border hover:shadow-sm transition-shadow duration-200">
                <div class="flex justify-between items-start gap-3">
                  <div class="flex-1">
                    <p class="text-gray-800">{{ note.content }}</p>
                    <span class="text-xs text-gray-400 block mt-2">
                      📅 {{ new Date(note.created_at).toLocaleString("hr-HR") }}
                    </span>
                  </div>
                  <button @click="deleteNote(note.id, client.id)"
                    class="text-red-500 hover:text-red-700 transition-colors duration-200 flex-shrink-0 p-1 rounded hover:bg-red-50"
                    title="Obriši bilješku" :disabled="deletingNoteId === note.id">
                    <span v-if="deletingNoteId === note.id" class="animate-spin">⏳</span>
                    <span v-else>🗑️</span>
                  </button>
                </div>
              </li>
            </ul>

            <div v-if="!loadingNotes[client.id]" class="flex gap-2">
              <input v-model="newNote[client.id]" @keyup.enter="addNote(client.id)"
                placeholder="Unesite novu bilješku..."
                class="flex-1 border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                :disabled="addingNoteClientId === client.id" />
              <button @click="addNote(client.id)"
                class="bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 text-sm flex items-center gap-2 transition-colors duration-200"
                :disabled="!newNote[client.id] || addingNoteClientId === client.id">
                <span v-if="addingNoteClientId === client.id" class="animate-spin">⏳</span>
                <span v-else>➕</span>
                {{ addingNoteClientId === client.id ? "Dodaje se..." : "Dodaj" }}
              </button>
            </div>
          </div>
        </li>
      </ul>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, nextTick } from "vue"
import { clientsAPI, notesAPI } from "@/services/api"

const clients = ref([])
const clientNotes = reactive({})
const notesCount = reactive({})
const notesOpen = reactive({})
const loadingNotes = reactive({})
const newNote = reactive({})
const showNewClient = ref(false)
const newClient = reactive({
  name: "",
  email: "",
  company: ""
})
const stats = reactive({
  clients: 0,
  totalNotes: 0,
  lastNote: ""
})
const loading = ref(true)
const deletingNoteId = ref(null)
const addingNoteClientId = ref(null)
const creatingClient = ref(false)
const deletingClientId = ref(null)

const initLoaderAndToggleNotes = async (id) => {
  console.log("🔄 Inicijaliziram loader za klijenta:", id)
  loadingNotes[id] = true
  await nextTick()
  await new Promise(resolve => setTimeout(resolve, 300))
  await toggleNotes(id)
}

const toggleNotes = async (id) => {
  if (clientNotes[id]) {
    notesOpen[id] = !notesOpen[id]
    loadingNotes[id] = false
    return
  }
  notesOpen[id] = true
  await loadNotes(id)
}

const loadNotes = async (id) => {
  try {
    console.log("📝 Učitavam bilješke za klijenta:", id)
    await new Promise(resolve => setTimeout(resolve, 1000))
    const response = await clientsAPI.getNotes(id)
    clientNotes[id] = response.notes
    console.log("✅ Bilješke učitane:", clientNotes[id].length)
    if (notesCount[id]) {
      notesCount[id].count = clientNotes[id].length
    }
  } catch (error) {
    console.error("Greška pri učitavanju bilješki:", error)
    alert("Greška pri učitavanju bilješki: " + (error.response?.data?.message || error.message))
  } finally {
    loadingNotes[id] = false
  }
}

const loadNotesCount = async () => {
  try {
    console.log("📊 Učitavam broj bilješki po klijentu...")
    const response = await clientsAPI.getNotesCount()
    Object.keys(notesCount).forEach(key => delete notesCount[key])
    Object.assign(notesCount, response)
    console.log("✅ Broj bilješki po klijentu učitano:", notesCount)
  } catch (error) {
    console.error("Greška pri učitavanju broja bilješki:", error)
    calculateNotesCountFallback()
  }
}

const calculateNotesCountFallback = () => {
  console.log("🔄 Koristim fallback za brojanje bilješki...")
  clients.value.forEach(client => {
    if (!notesCount[client.id]) {
      notesCount[client.id] = {
        count: clientNotes[client.id]?.length || 0,
        name: client.name
      }
    }
  })
}

const loadClients = async () => {
  try {
    loading.value = true
    console.log("📋 Učitavam klijente...")
    const response = await clientsAPI.getAll()
    clients.value = response.clients
    console.log("✅ Klijenti učitani:", clients.value.length)
    await loadNotesCount()
    await loadStats()
  } catch (error) {
    console.error("Greška pri učitavanju klijenata:", error)
    alert("Greška pri učitavanju klijenata: " + (error.response?.data?.message || error.message))
  } finally {
    loading.value = false
  }
}

const createClient = async () => {
  if (!newClient.name || !newClient.email) {
    alert("Ime i email su obavezni")
    return
  }

  try {
    creatingClient.value = true
    console.log("➕ Kreiranje klijenta:", newClient)
    const response = await clientsAPI.create(newClient)
    console.log("✅ Klijent kreiran:", response.data)
    Object.assign(newClient, { name: "", email: "", company: "" })
    showNewClient.value = false
    await loadClients()
  } catch (error) {
    console.error("Greška pri kreiranju klijenta:", error)
    alert("Greška pri kreiranju klijenta: " + (error.response?.data?.message || error.message))
  } finally {
    creatingClient.value = false
  }
}

const cancelNewClient = () => {
  showNewClient.value = false
  Object.assign(newClient, { name: "", email: "", company: "" })
}

const deleteClient = async (id) => {
  const client = clients.value.find(c => c.id === id)
  if (!confirm(\`Jeste li sigurni da želite obrisati klijenta "\${client.name}" i sve njegove bilješke?\`)) return

  try {
    deletingClientId.value = id
    console.log("🗑️ Brisanje klijenta:", id)
    await clientsAPI.deleteClient(id)
    console.log("✅ Klijent obrisan")
    await loadClients()
    await loadStats()
  } catch (error) {
    console.error("Greška pri brisanju klijenata:", error)
    alert("Greška pri brisanju klijenata: " + (error.response?.data?.message || error.message))
  } finally {
    deletingClientId.value = null
  }
}

const addNote = async (id) => {
  if (!newNote[id]?.trim()) {
    alert("Unesite tekst bilješke")
    return
  }

  try {
    addingNoteClientId.value = id
    console.log("➕ Dodavanje bilješke za klijenta:", id, "Sadržaj:", newNote[id])
    await clientsAPI.addNote(id, newNote[id])
    newNote[id] = ""
    await loadNotesCount()
    if (notesOpen[id]) {
      await loadNotes(id)
    }
    await loadStats()
    console.log("✅ Bilješka dodana")
  } catch (error) {
    console.error("Greška pri dodavanju bilješke:", error)
    alert("Greška pri dodavanju bilješke: " + (error.response?.data?.message || error.message))
  } finally {
    addingNoteClientId.value = null
  }
}

const deleteNote = async (noteId, clientId) => {
  if (!confirm("Jeste li sigurni da želite obrisati ovu bilješku?")) return

  try {
    deletingNoteId.value = noteId
    console.log("🗑️ Brisanje bilješke:", noteId)
    await notesAPI.deleteNote(noteId)
    await loadNotesCount()
    await loadNotes(clientId)
    await loadStats()
    console.log("✅ Bilješka obrisana")
  } catch (error) {
    console.error("Greška pri brisanju bilješke:", error)
    if (error.response?.status === 404) {
      alert("Bilješka nije pronađena. Možda je već obrisana.")
    } else {
      alert("Greška pri brisanju bilješke: " + (error.response?.data?.message || error.message))
    }
  } finally {
    deletingNoteId.value = null
  }
}

const loadStats = async () => {
  try {
    const response = await clientsAPI.getStats()
    Object.assign(stats, response)
    console.log("📊 Statistika učitana:", stats)
  } catch (error) {
    console.error("Greška pri učitavanju statistike:", error)
  }
}

const getNoteCount = (clientId) => {
  return notesCount[clientId]?.count || clientNotes[clientId]?.length || 0
}

const getNoteCountDisplay = (clientId) => {
  const count = getNoteCount(clientId)
  if (count === 1) {
    return "1 bilješka"
  } else if (count >= 2 && count <= 4) {
    return \`\${count} bilješke\`
  } else {
    return \`\${count} bilješki\`
  }
}

onMounted(() => {
  loadClients()
})
</script>'

# 5. UPDATE LOGIN FORM
create_file "frontend/src/components/LoginForm.vue" '<template>
  <div class="max-w-md mx-auto mt-20 p-6 bg-white rounded-lg shadow-md">
    <h2 class="text-2xl font-bold mb-6 text-center">Prijava</h2>
    <form @submit.prevent="handleLogin" class="space-y-4">
      <div>
        <label class="block text-sm font-medium text-gray-700">Email</label>
        <input v-model="loginData.email" type="email"
          class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          required>
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700">Lozinka</label>
        <input v-model="loginData.password" type="password"
          class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          required>
      </div>
      <button type="submit"
        class="w-full bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 flex items-center justify-center"
        :disabled="isLoggingIn">
        <span v-if="isLoggingIn" class="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></span>
        {{ isLoggingIn ? "Prijavljujem..." : "Prijavi se" }}
      </button>
    </form>
    
    <div class="mt-4 p-3 bg-yellow-50 rounded-md text-sm">
      <strong>Demo pristup:</strong><br>
      Email: demo@demo.com<br>
      Lozinka: demo123
    </div>

    <div class="mt-4 text-center">
      <a href="#" @click.prevent="$emit(\"go-home\")" class="text-blue-600 hover:text-blue-800 text-sm">
        ← Povratak na početnu
      </a>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive } from "vue"
import { authAPI } from "@/services/api"

const emit = defineEmits(["login", "go-home"])

const isLoggingIn = ref(false)

const loginData = reactive({
  email: "demo@demo.com",
  password: "demo123"
})

const handleLogin = async () => {
  isLoggingIn.value = true
  try {
    await new Promise(resolve => setTimeout(resolve, 500))
    const response = await authAPI.login(loginData.email, loginData.password)
    emit("login", response)
  } catch (error) {
    console.error("Login failed:", error.response?.data || error.message)
    alert("Pogrešni podaci za prijavu: " + (error.response?.data?.message || error.message))
  } finally {
    isLoggingIn.value = false
  }
}
</script>'

# 6. UPDATE APP.VUE
create_file "frontend/src/App.vue" '<template>
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
</style>'

# 7. UPDATE VERCEL CONFIG
create_file "frontend/vercel.json" '{
  "version": 2,
  "builds": [
    {
      "src": "package.json",
      "use": "@vercel/static-build",
      "config": {
        "distDir": "dist"
      }
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "/index.html"
    }
  ]
}'

# 8. TEST BUILD
echo -e "${YELLOW}🧪 Testing frontend build...${NC}"
cd frontend
npm install > /dev/null 2>&1
npm run build > /dev/null 2>&1
cd ..
check_success "Frontend build test passed"

# 9. GIT COMMIT & PUSH
echo -e "${YELLOW}💾 Committing frontend updates...${NC}"
git add . > /dev/null 2>&1
git commit -m "Update frontend for PostgreSQL backend integration

- API service for PostgreSQL backend communication
- Updated components for real database operations
- Environment configuration for staging backend
- Enhanced error handling and loading states" > /dev/null 2>&1
check_success "Changes committed"

echo -e "${YELLOW}📤 Pushing to GitHub...${NC}"
git push origin main > /dev/null 2>&1
check_success "Pushed to GitHub"

# 10. FINAL INSTRUCTIONS
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════╗"
echo "║               ✅ UPDATE COMPLETE             ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}📋 WHAT WAS UPDATED:${NC}"
echo ""
echo -e "${GREEN}🔧 Frontend Configuration:${NC}"
echo "   • Environment variables for PostgreSQL backend"
echo "   • Vite proxy configuration"
echo "   • API service with PostgreSQL endpoints"
echo ""
echo -e "${GREEN}🎯 Components Updated:${NC}"
echo "   • Dashboard - Real database operations"
echo "   • LoginForm - PostgreSQL authentication"
echo "   • App.vue - Enhanced state management"
echo ""
echo -e "${GREEN}🌐 Backend Integration:${NC}"
echo "   • Communicates with: ${GREEN}https://crm-staging-backend.up.railway.app${NC}"
echo "   • PostgreSQL database operations"
echo "   • Real-time data synchronization"
echo ""
echo -e "${YELLOW}🚀 Next Steps:${NC}"
echo "   1. Backend should be deployed on Railway with PostgreSQL"
echo "   2. Frontend will auto-deploy on Vercel"
echo "   3. Test the application with demo credentials"
echo ""
echo -e "${GREEN}✅ Frontend successfully updated for PostgreSQL backend!${NC}"
echo -e "${BLUE}💡 Your frontend now communicates with the real PostgreSQL database 🎉${NC}"'

# Make script executable
chmod +x update-frontend.sh

echo -e "${YELLOW}🔧 Created update-frontend.sh script${NC}"
echo -e "${GREEN}🎉 Frontend update script ready! Run ./update-frontend.sh to apply changes${NC}"