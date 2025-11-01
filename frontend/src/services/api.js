import axios from "axios"

// ⭐⭐⭐ ISPRAVITE OVO - koristite Railway URL ⭐⭐⭐
const API_URL = "https://crm-staging-app.up.railway.app"

console.log('🚀 API Service initialized with URL:', API_URL)

const api = axios.create({
  baseURL: API_URL,
  headers: {
    "Content-Type": "application/json",
  },
})

// Add detailed request logging
api.interceptors.request.use((config) => {
  console.log('📡 Making request to:', config.baseURL + config.url)
  console.log('🔧 Request config:', {
    method: config.method,
    url: config.url,
    baseURL: config.baseURL,
    data: config.data
  })
  return config
})

// Add response logging
api.interceptors.response.use(
  (response) => {
    console.log('✅ Response received from:', response.config.url)
    console.log('📦 Response data:', response.data)
    return response
  },
  (error) => {
    console.error('❌ API Error:', {
      url: error.config?.baseURL + error.config?.url,
      status: error.response?.status,
      message: error.response?.data?.message || error.message
    })
    return Promise.reject(error)
  }
)

// Auth API
export const authAPI = {
  login: async (email, password) => {
    console.log('🔐 authAPI.login called with:', { email })
    const response = await api.post("/api/login", { email, password })
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
    const response = await api.get(`/api/clients/${clientId}/notes`)
    return response.data
  },
  
  addNote: async (clientId, content) => {
    const response = await api.post(`/api/clients/${clientId}/notes`, { content })
    return response.data
  },

  deleteClient: async (clientId) => {
    const response = await api.delete(`/api/clients/${clientId}`)
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
    const response = await api.delete(`/api/notes/${noteId}`)
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

// ⭐⭐⭐ CACHE BUSTING - FORCE NEW VERSION ⭐⭐⭐
console.log('🔄 API Cache Busting Timestamp:', Date.now())
console.log('✅ API URL Verified:', API_URL)

// Force version check
if (typeof window !== 'undefined') {
  window.API_VERSION = 'v2-' + Date.now()
  console.log('🚀 API Version:', window.API_VERSION)
}

export default api