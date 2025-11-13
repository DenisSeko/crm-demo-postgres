<template>
  <div class="max-w-6xl mx-auto p-6">
    <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
      <div class="bg-white p-6 rounded-lg shadow-sm border">
        <h3 class="text-lg font-semibold text-gray-700">Ukupno klijenata</h3>
        <p class="text-3xl font-bold text-blue-600">{{ stats.clients }}</p>
        <div class="text-xs text-gray-500 mt-1 space-y-1">
          <div>📝 S bilješkama: {{ getClientsWithNotes() }}</div>
          <div>📄 Bez bilješki: {{ getClientsWithoutNotes() }}</div>
        </div>
      </div>
      <div class="bg-white p-6 rounded-lg shadow-sm border">
        <h3 class="text-lg font-semibold text-gray-700">Ukupno bilješki</h3>
        <p class="text-3xl font-bold text-green-600">{{ stats.totalNotes }}</p>
        <p class="text-xs text-gray-500 mt-1">
          Prosjek: {{ getAverageNotes() }} po klijentu
        </p>
      </div>
      <div class="bg-white p-6 rounded-lg shadow-sm border">
        <h3 class="text-lg font-semibold text-gray-700">Zadnja bilješka</h3>
        <p class="text-sm text-gray-600 mt-1 truncate" :title="stats.lastNote">
          {{ stats.lastNote }}
        </p>
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
          {{ creatingClient ? 'Spremanje...' : 'Spremi' }}
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
          <div class="text-sm text-gray-600 space-y-1">
            <div>
              Ukupno bilješki: <span class="font-bold text-green-600">{{ stats.totalNotes }}</span>
            </div>
            <div class="text-xs">
              Prosjek: <span class="font-semibold">{{ getAverageNotes() }}</span> po klijentu
            </div>
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
                {{ client.company || 'Nema podataka o tvrtki' }}
              </p>
              <p class="text-xs text-gray-400 mt-2">
                Kreiran: {{ new Date(client.created_at).toLocaleDateString('hr-HR') }}
              </p>
            </div>
            <div class="flex gap-2">
              <button @click="initLoaderAndToggleNotes(client.id)"
                class="text-blue-600 hover:text-blue-800 px-3 py-2 rounded border border-blue-200 hover:bg-blue-50 transition-colors duration-200 flex items-center gap-2"
                :title="notesOpen[client.id] ? 'Sakrij bilješke' : 'Prikaži bilješke'"
                :disabled="loadingNotes[client.id]">
                <span>{{ notesOpen[client.id] ? '📕' : '📘' }}</span>
                
                <template v-if="loadingNotes[client.id]">
                  <div class="flex items-center gap-1">
                    <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-500"></div>
                    Učitavanje...
                  </div>
                </template>
                <template v-else>
                  {{ notesOpen[client.id] ? 'Sakrij' : 'Bilješke' }} ({{ getNoteCountDisplay(client.id) }})
                </template>
              </button>
              <button @click="deleteClient(client.id)"
                class="text-red-600 hover:text-red-800 px-3 py-2 rounded border border-red-200 hover:bg-red-50 transition-colors duration-200 flex items-center gap-2"
                title="Obriši klijenta"
                :disabled="deletingClientId === client.id">
                <span v-if="deletingClientId === client.id" class="animate-spin">⏳</span>
                <span v-else>🗑️</span>
                {{ deletingClientId === client.id ? 'Briše se...' : 'Obriši' }}
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
                      📅 {{ new Date(note.created_at).toLocaleString('hr-HR') }}
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
                {{ addingNoteClientId === client.id ? 'Dodaje se...' : 'Dodaj' }}
              </button>
            </div>
          </div>
        </li>
      </ul>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, nextTick } from 'vue'
import api from '../services/api'

const clients = ref([])
const clientNotes = reactive({})
const notesCount = reactive({})
const notesOpen = reactive({})
const loadingNotes = reactive({})
const newNote = reactive({})
const showNewClient = ref(false)
const newClient = reactive({
  name: '',
  email: '',
  company: ''
})
const stats = reactive({
  clients: 0,
  totalNotes: 0,
  lastNote: 'Nema bilježki'
})
const loading = ref(true)
const deletingNoteId = ref(null)
const addingNoteClientId = ref(null)
const creatingClient = ref(false)
const deletingClientId = ref(null)

const initLoaderAndToggleNotes = async (id) => {
  console.log('🔄 Inicijaliziram loader za klijenta:', id)
  
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
    console.log('📝 Učitavam bilješke za klijenta:', id)
    await new Promise(resolve => setTimeout(resolve, 1000))
    
    const response = await api.get(`/clients/${id}/notes`)
    clientNotes[id] = response.data
    console.log('✅ Bilješke učitane:', clientNotes[id].length)
    
    if (notesCount[id]) {
      notesCount[id].count = clientNotes[id].length
    }
  } catch (error) {
    console.error('Greška pri učitavanju bilješki:', error)
    alert('Greška pri učitavanju bilješki: ' + (error.response?.data?.error || error.message))
  } finally {
    loadingNotes[id] = false
  }
}

const loadNotesCount = async () => {
  try {
    console.log('📊 Učitavam broj bilješki po klijentu...')
    const response = await api.get('/clients/notes-count')
    
    Object.keys(notesCount).forEach(key => delete notesCount[key])
    Object.assign(notesCount, response.data)
    console.log('✅ Broj bilješki po klijentu učitano:', notesCount)
  } catch (error) {
    console.error('Greška pri učitavanju broja bilješki:', error)
    calculateNotesCountFallback()
  }
}

const calculateNotesCountFallback = () => {
  console.log('🔄 Koristim fallback za brojanje bilješki...')
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
    console.log('📋 Učitavam klijente...')
    const response = await api.get('/clients')
    clients.value = response.data
    console.log('✅ Klijenti učitani:', clients.value.length)
    
    // UČITAJ SVE POTREBNE PODATKE
    await loadStats()
    await loadNotesCount()
    await findLastNoteFromData() // OVO JE KLJUČNA PROMJENA
    
  } catch (error) {
    console.error('Greška pri učitavanju klijenata:', error)
    alert('Greška pri učitavanju klijenata: ' + (error.response?.data?.error || error.message))
  } finally {
    loading.value = false
  }
}

const loadStats = async () => {
  try {
    const response = await api.get('/clients/stats')
    const serverStats = response.data
    
    console.log('📊 Podaci s backenda:', serverStats)
    
    const adaptedStats = {
      clients: serverStats.totalClients || 0,
      totalNotes: serverStats.totalNotes || 0,
      lastNote: 'Učitavam...'
    }
    
    Object.assign(stats, adaptedStats)
    console.log('✅ Statistika adaptirana:', stats)
    
  } catch (error) {
    console.error('Greška pri učitavanju statistike:', error)
    stats.clients = clients.value.length
    stats.totalNotes = calculateTotalNotes()
    stats.lastNote = findLastNoteContent()
  }
}

// NOVA FUNKCIJA - ne koristi /notes/latest endpoint
const findLastNoteFromData = async () => {
  try {
    console.log('🔍 Tražim zadnju bilješku iz postojećih podataka...')
    
    // Prvo pokušaj pronaći iz već učitane notesCount
    if (stats.totalNotes > 0) {
      console.log('📝 Pokušavam učitati sve bilješke za pronalaženje zadnje...')
      
      // Pokušaj učitati sve bilješke preko postojećeg endpointa
      try {
        const response = await api.get('/notes')
        if (response.data && response.data.length > 0) {
          const latestNote = response.data.reduce((latest, note) => {
            const noteDate = new Date(note.created_at)
            const latestDate = latest ? new Date(latest.created_at) : null
            return !latestDate || noteDate > latestDate ? note : latest
          }, null)
          
          if (latestNote) {
            stats.lastNote = latestNote.content
            console.log('✅ Zadnja bilješka pronađena:', stats.lastNote)
            return
          }
        }
      } catch (error) {
        console.log('ℹ️ Endpoint /notes nije dostupan, pokušavam drugi način...')
      }
    }
    
    // Ako gornji način ne uspije, pokušaj iz clientNotes
    const lastNoteFromClientNotes = findLastNoteContent()
    if (lastNoteFromClientNotes !== 'Nema bilježki') {
      stats.lastNote = lastNoteFromClientNotes
      console.log('✅ Zadnja bilješka pronađena iz clientNotes:', stats.lastNote)
      return
    }
    
    // Ako nema bilješki
    stats.lastNote = 'Nema bilježki'
    console.log('ℹ️ Nema bilježki u sustavu')
    
  } catch (error) {
    console.error('Greška pri pronalaženju zadnje bilješke:', error)
    stats.lastNote = findLastNoteContent()
  }
}

const calculateTotalNotes = () => {
  if (stats.totalNotes > 0) {
    return stats.totalNotes
  }
  
  let total = 0
  Object.values(notesCount).forEach(item => {
    total += item.count || 0
  })
  
  if (total === 0 && clients.value.length > 0) {
    Object.values(clientNotes).forEach(notes => {
      if (Array.isArray(notes)) {
        total += notes.length
      }
    })
  }
  
  return total
}

const findLastNoteContent = () => {
  let lastNote = null
  let lastDate = null
  
  Object.values(clientNotes).forEach(notes => {
    if (Array.isArray(notes)) {
      notes.forEach(note => {
        if (note && note.created_at) {
          const noteDate = new Date(note.created_at)
          if (!lastDate || noteDate > lastDate) {
            lastDate = noteDate
            lastNote = note.content
          }
        }
      })
    }
  })
  
  return lastNote || 'Nema bilježki'
}

const createClient = async () => {
  if (!newClient.name || !newClient.email) {
    alert('Ime i email su obavezni')
    return
  }

  try {
    creatingClient.value = true
    console.log('➕ Kreiranje klijenta:', newClient)
    const response = await api.post('/clients', newClient)
    console.log('✅ Klijent kreiran:', response.data)
    
    Object.assign(newClient, { name: '', email: '', company: '' })
    showNewClient.value = false
    await loadClients()
  } catch (error) {
    console.error('Greška pri kreiranju klijenta:', error)
    alert('Greška pri kreiranju klijenta: ' + (error.response?.data?.error || error.message))
  } finally {
    creatingClient.value = false
  }
}

const cancelNewClient = () => {
  showNewClient.value = false
  Object.assign(newClient, { name: '', email: '', company: '' })
}

const deleteClient = async (id) => {
  const client = clients.value.find(c => c.id === id)
  if (!confirm(`Jeste li sigurni da želite obrisati klijenta "${client.name}" i sve njegove bilješke?`)) return

  try {
    deletingClientId.value = id
    console.log('🗑️ Brisanje klijenta:', id)
    await api.delete(`/clients/${id}`)
    console.log('✅ Klijent obrisan')
    
    await loadClients()
  } catch (error) {
    console.error('Greška pri brisanju klijenata:', error)
    alert('Greška pri brisanju klijenata: ' + (error.response?.data?.error || error.message))
  } finally {
    deletingClientId.value = null
  }
}

const addNote = async (id) => {
  if (!newNote[id]?.trim()) {
    alert('Unesite tekst bilješke')
    return
  }

  try {
    addingNoteClientId.value = id
    console.log('➕ Dodavanje bilješke za klijenta:', id, 'Sadržaj:', newNote[id])
    await api.post(`/clients/${id}/notes`, { content: newNote[id] })
    newNote[id] = ''
    
    await loadNotesCount()
    if (notesOpen[id]) {
      await loadNotes(id)
    }
    await loadStats()
    await findLastNoteFromData()
    console.log('✅ Bilješka dodana')
  } catch (error) {
    console.error('Greška pri dodavanju bilješke:', error)
    alert('Greška pri dodavanju bilješke: ' + (error.response?.data?.error || error.message))
  } finally {
    addingNoteClientId.value = null
  }
}

const deleteNote = async (noteId, clientId) => {
  if (!confirm('Jeste li sigurni da želite obrisati ovu bilješku?')) return

  try {
    deletingNoteId.value = noteId
    console.log('🗑️ Brisanje bilješke:', noteId)
    
    await api.delete(`/notes/${noteId}`)
    
    await loadNotesCount()
    await loadNotes(clientId)
    await loadStats()
    await findLastNoteFromData()
    console.log('✅ Bilješka obrisana')
  } catch (error) {
    console.error('Greška pri brisanju bilješke:', error)
    
    if (error.response?.status === 404) {
      alert('Bilješka nije pronađena. Možda je već obrisana.')
    } else {
      alert('Greška pri brisanju bilješke: ' + (error.response?.data?.error || error.message))
    }
  } finally {
    deletingNoteId.value = null
  }
}

const getClientsWithNotes = () => {
  if (clients.value.length === 0) return '0'
  
  let count = 0
  clients.value.forEach(client => {
    if (getNoteCount(client.id) > 0) {
      count++
    }
  })
  return count.toString()
}

const getClientsWithoutNotes = () => {
  if (clients.value.length === 0) return '0'
  
  let count = 0
  clients.value.forEach(client => {
    if (getNoteCount(client.id) === 0) {
      count++
    }
  })
  return count.toString()
}

const getAverageNotes = () => {
  if (stats.totalNotes === 0 || stats.clients === 0) return '0.00'
  
  const average = stats.totalNotes / stats.clients
  return average.toFixed(2)
}

const getNoteCount = (clientId) => {
  return notesCount[clientId]?.count || clientNotes[clientId]?.length || 0
}

const getNoteCountDisplay = (clientId) => {
  const count = getNoteCount(clientId)
  
  if (count === 1) {
    return '1 bilješka'
  } else if (count >= 2 && count <= 4) {
    return `${count} bilješke`
  } else {
    return `${count} bilješki`
  }
}

onMounted(() => {
  loadClients()
})
</script>