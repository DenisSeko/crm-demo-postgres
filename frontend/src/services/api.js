import axios from "axios"

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

export default api
