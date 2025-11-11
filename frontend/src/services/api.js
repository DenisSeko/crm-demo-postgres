import axios from 'axios';

// Odredi base URL ovisno o okruženju
const API_BASE = import.meta.env.MODE === 'development' 
  ? 'http://localhost:8888/api'
  : '/api';

console.log('🔧 API Base URL:', API_BASE);

// Kreiraj axios instancu s base URL-om
const api = axios.create({
  baseURL: API_BASE,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor za logging
api.interceptors.request.use(
  (config) => {
    console.log(`🚀 API Call: ${config.method?.toUpperCase()} ${config.url}`);
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor za error handling
api.interceptors.response.use(
  (response) => {
    return response;
  },
  (error) => {
    console.error('💥 API Error:', error.response?.data || error.message);
    return Promise.reject(error);
  }
);

export default api;
