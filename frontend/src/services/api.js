import axios from "axios"

// ⭐⭐⭐ NETLIFY OPTIMIZED - koristi relative paths ⭐⭐⭐
const API_URL = ""  // Prazno za relative paths + Netlify redirects

console.log('🚀 API Service initialized for Netlify deployment')
console.log('📍 Using relative paths with Netlify redirects')

const api = axios.create({
  baseURL: API_URL,
  headers: {
    "Content-Type": "application/json",
  },
})

// Add detailed request logging
api.interceptors.request.use((config) => {
  const fullUrl = config.baseURL + config.url
  console.log('📡 Making API request to:', fullUrl)
  console.log('🔧 Request details:', {
    method: config.method?.toUpperCase(),
    endpoint: config.url,
    fullURL: fullUrl,
    hasData: !!config.data
  })
  return config
})

// Add response logging
api.interceptors.response.use(
  (response) => {
    console.log('✅ API Response success:', {
      endpoint: response.config.url,
      status: response.status,
      data: response.data
    })
    return response
  },
  (error) => {
    console.error('❌ API Error occurred:', {
      url: error.config?.url,
      status: error.response?.status,
      message: error.response?.data?.message || error.message,
      fullError: error.response?.data
    })
    return Promise.reject(error)
  }
)

// Auth API
export const authAPI = {
  login: async (email, password) => {
    console.log('🔐 Auth login initiated for:', email)
    const response = await api.post("/api/login", { email, password })
    console.log('🔑 Login response received')
    return response.data
  },
}

// Clients API  
export const clientsAPI = {
  getAll: async () => {
    console.log('👥 Fetching all clients')
    const response = await api.get("/api/clients")
    return response.data
  },
  
  create: async (clientData) => {
    console.log('➕ Creating new client:', clientData.name)
    const response = await api.post("/api/clients", clientData)
    return response.data
  },
  
  getNotes: async (clientId) => {
    console.log('📝 Fetching notes for client:', clientId)
    const response = await api.get(`/api/clients/${clientId}/notes`)
    return response.data
  },
  
  addNote: async (clientId, content) => {
    console.log('📋 Adding note to client:', clientId)
    const response = await api.post(`/api/clients/${clientId}/notes`, { content })
    return response.data
  },

  deleteClient: async (clientId) => {
    console.log('🗑️ Deleting client:', clientId)
    const response = await api.delete(`/api/clients/${clientId}`)
    return response.data
  },

  getStats: async () => {
    console.log('📊 Fetching client statistics')
    const response = await api.get("/api/clients/stats")
    return response.data
  },

  getNotesCount: async () => {
    console.log('🔢 Fetching notes count')
    const response = await api.get("/api/clients/notes-count")
    return response.data
  }
}

// Notes API
export const notesAPI = {
  deleteNote: async (noteId) => {
    console.log('🗑️ Deleting note:', noteId)
    const response = await api.delete(`/api/notes/${noteId}`)
    return response.data
  }
}

// Health check
export const healthAPI = {
  check: async () => {
    console.log('🏥 Performing health check')
    const response = await api.get("/api/health")
    return response.data
  },
}

// ⭐⭐⭐ NETLIFY DEPLOYMENT READY ⭐⭐⭐
console.log('✅ API Service configured for Netlify:')
console.log('   - Using relative paths (/api/*)')
console.log('   - Netlify will proxy to Railway backend')
console.log('   - No CORS issues expected')

// Deployment info
if (typeof window !== 'undefined') {
  window.API_CONFIG = {
    version: 'netlify-1.0',
    baseURL: API_URL,
    deployment: 'netlify-proxy'
  }
  console.log('🚀 API Configuration:', window.API_CONFIG)
}

export default api