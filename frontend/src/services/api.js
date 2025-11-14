// services/api.js
import axios from 'axios';

// Dinamičko određivanje baseURL-a za različite environmente
const getApiConfig = () => {
  // Provjeri jesmo li u browseru
  if (typeof window === 'undefined') {
    return {
      baseURL: 'http://localhost:8888/api',
      timeout: 10000,
    };
  }

  // Za development na localhostu
  if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
    return {
      baseURL: 'http://localhost:8888/api',
      timeout: 10000,
    };
  }

  // Za Upsun staging/production - koristi relative path
  // Upsun će servirati API preko /api rute
  return {
    baseURL: '/api',
    timeout: 15000, // Povećaj timeout za produkciju
  };
};

// Kreiraj axios instancu sa dinamičkim base URL-om
const api = axios.create(getApiConfig());

// Auth helper sa kompletnom funkcionalnošću
export const authHelper = {
  setAuth(token, user) {
    try {
      localStorage.setItem('authToken', token);
      localStorage.setItem('user', JSON.stringify(user));
      localStorage.setItem('isAuthenticated', 'true');
      localStorage.setItem('authTimestamp', Date.now().toString());
      console.log('🔐 Auth podaci spremljeni:', { 
        token: token ? `${token.substring(0, 20)}...` : 'empty',
        user: { id: user?.id, email: user?.email, role: user?.role }
      });
      
      // Postavi default Authorization header
      api.defaults.headers.common['Authorization'] = `Bearer ${token}`;
    } catch (error) {
      console.error('❌ Greška pri spremanju auth podataka:', error);
    }
  },
  
  clearAuth() {
    try {
      localStorage.removeItem('authToken');
      localStorage.removeItem('user');
      localStorage.removeItem('isAuthenticated');
      localStorage.removeItem('authTimestamp');
      delete api.defaults.headers.common['Authorization'];
      console.log('🔐 Auth podaci očišćeni');
    } catch (error) {
      console.error('❌ Greška pri čišćenju auth podataka:', error);
    }
  },
  
  getToken() {
    try {
      return localStorage.getItem('authToken');
    } catch (error) {
      console.error('❌ Greška pri dobivanju tokena:', error);
      return null;
    }
  },
  
  getUser() {
    try {
      const user = localStorage.getItem('user');
      return user ? JSON.parse(user) : null;
    } catch (error) {
      console.error('❌ Greška pri dobivanju korisnika:', error);
      return null;
    }
  },
  
  isAuthenticated() {
    try {
      const token = this.getToken();
      const user = this.getUser();
      const isAuthenticated = localStorage.getItem('isAuthenticated') === 'true';
      
      const authenticated = !!(token && user && isAuthenticated && !this.isTokenExpired());
      console.log('🔐 Auth status:', { authenticated, hasToken: !!token, hasUser: !!user, isExpired: this.isTokenExpired() });
      
      return authenticated;
    } catch (error) {
      console.error('❌ Greška pri provjeri autentikacije:', error);
      return false;
    }
  },
  
  isTokenExpired() {
    const token = this.getToken();
    if (!token) {
      console.log('⚠️ Nema tokena za provjeru');
      return true;
    }
    
    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      const isExpired = payload.exp * 1000 < Date.now();
      
      if (isExpired) {
        console.log('⚠️ Token je istekao:', new Date(payload.exp * 1000).toLocaleString('hr-HR'));
        this.clearAuth();
      } else {
        console.log('✅ Token je validan do:', new Date(payload.exp * 1000).toLocaleString('hr-HR'));
      }
      
      return isExpired;
    } catch (error) {
      console.error('❌ Greška pri provjeri tokena:', error);
      this.clearAuth();
      return true;
    }
  },
  
  initializeAuth() {
    try {
      const token = this.getToken();
      if (token && !this.isTokenExpired()) {
        api.defaults.headers.common['Authorization'] = `Bearer ${token}`;
        console.log('🔐 Auth inicijaliziran iz localStorage');
        return true;
      } else {
        console.log('🔐 Nema validnog tokena za inicijalizaciju');
        this.clearAuth();
        return false;
      }
    } catch (error) {
      console.error('❌ Greška pri inicijalizaciji auth:', error);
      this.clearAuth();
      return false;
    }
  },

  // Dodatna helper metoda za debug
  getAuthInfo() {
    return {
      hasToken: !!this.getToken(),
      hasUser: !!this.getUser(),
      isAuthenticated: this.isAuthenticated(),
      isTokenExpired: this.isTokenExpired(),
      user: this.getUser(),
      tokenPreview: this.getToken() ? `${this.getToken().substring(0, 20)}...` : null
    };
  }
};

// Request interceptor za automatsko dodavanje tokena
api.interceptors.request.use(
  (config) => {
    const token = authHelper.getToken();
    
    if (token && !authHelper.isTokenExpired()) {
      config.headers.Authorization = `Bearer ${token}`;
      console.log(`🚀 ${config.method?.toUpperCase()} ${config.url} [AUTH]`);
    } else {
      console.log(`🚀 ${config.method?.toUpperCase()} ${config.url} [NO AUTH]`);
      
      // Ako je token istekao, očistimo ga
      if (token && authHelper.isTokenExpired()) {
        authHelper.clearAuth();
      }
    }
    
    // Log samo osnovne informacije za sigurnost
    console.log(`📤 Request: ${config.method?.toUpperCase()} ${config.url}`, {
      hasData: !!config.data,
      hasParams: !!config.params
    });
    
    return config;
  },
  (error) => {
    console.error('❌ Request error:', error);
    return Promise.reject({
      ...error,
      userMessage: 'Problem s mrežnom vezom. Provjerite internetsku vezu.'
    });
  }
);

// Response interceptor za handling grešaka
api.interceptors.response.use(
  (response) => {
    console.log(`✅ ${response.config.method?.toUpperCase()} ${response.config.url}: ${response.status}`);
    return response;
  },
  (error) => {
    const url = error.config?.url;
    const method = error.config?.method;
    const status = error.response?.status;
    const message = error.response?.data?.error || error.message;
    const errorCode = error.response?.data?.code;

    console.error(`❌ API Error ${status} [${method?.toUpperCase()} ${url}]:`, {
      message,
      code: errorCode,
      userMessage: error.response?.data?.error || 'Došlo je do greške'
    });

    // Automatski logout ako je token invalid
    if (status === 401) {
      console.log('🔐 401 Unauthorized - clearing auth');
      authHelper.clearAuth();
      
      // Redirect na login samo ako nismo već na login stranici
      if (typeof window !== 'undefined') {
        const currentPath = window.location.pathname + window.location.search;
        if (!currentPath.includes('login') && !currentPath.includes('auth=login')) {
          console.log('🔄 Redirecting to login...');
          setTimeout(() => {
            window.location.href = '/?auth=login&message=session_expired';
          }, 1500);
        }
      }
    }

    // Network error - posebno važno za Upsun
    if (error.code === 'NETWORK_ERROR' || error.message === 'Network Error') {
      console.error('🌐 Network Error - provjeri internet konekciju ili server status');
    }

    // Kreiraj user-friendly poruku
    let userMessage = 'Došlo je do greške. Pokušajte ponovno.';
    
    if (!error.response) {
      userMessage = 'Problem s mrežnom vezom. Provjerite internetsku vezu.';
    } else if (status >= 500) {
      userMessage = 'Server trenutno nije dostupan. Pokušajte ponovno kasnije.';
    } else if (status === 404) {
      userMessage = 'Traženi resurs nije pronađen.';
    } else if (status === 403) {
      userMessage = 'Nemate dovoljne privilegije za ovu akciju.';
    } else if (message) {
      userMessage = message;
    }

    // Proslijedi poboljšani error
    return Promise.reject({
      ...error,
      userMessage,
      errorCode,
      originalMessage: message,
      // Dodatne informacije za debug
      isNetworkError: !error.response,
      isServerError: status >= 500,
      isClientError: status >= 400 && status < 500
    });
  }
);

// Utility funkcije za često korištene operacije
export const apiUtils = {
  // Brzi GET zahtjev sa error handlingom
  async safeGet(url, config = {}) {
    try {
      const response = await api.get(url, config);
      return response.data;
    } catch (error) {
      console.error(`❌ Safe GET error for ${url}:`, error.userMessage || error.message);
      throw error;
    }
  },

  // Brzi POST zahtjev sa error handlingom
  async safePost(url, data = {}, config = {}) {
    try {
      const response = await api.post(url, data, config);
      return response.data;
    } catch (error) {
      console.error(`❌ Safe POST error for ${url}:`, error.userMessage || error.message);
      throw error;
    }
  },

  // Provjera da li je backend dostupan
  async healthCheck() {
    try {
      const response = await api.get('/health');
      return {
        status: response.status === 200,
        data: response.data,
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      console.error('❌ Health check failed:', error.message);
      return {
        status: false,
        error: error.message,
        timestamp: new Date().toISOString()
      };
    }
  },

  // Test API konekcije - za debug
  async testConnection() {
    try {
      const startTime = Date.now();
      const response = await api.get('/');
      const endTime = Date.now();
      
      return {
        success: true,
        responseTime: endTime - startTime,
        data: response.data,
        status: response.status
      };
    } catch (error) {
      return {
        success: false,
        error: error.message,
        userMessage: error.userMessage
      };
    }
  }
};

// Globalna funkcija za debug auth stanja
export const debugAuth = () => {
  const authInfo = authHelper.getAuthInfo();
  console.group('🔐 Auth Debug Info');
  console.log('Authenticated:', authInfo.isAuthenticated);
  console.log('Has Token:', authInfo.hasToken);
  console.log('Has User:', authInfo.hasUser);
  console.log('Token Expired:', authInfo.isTokenExpired);
  console.log('User:', authInfo.user);
  console.log('Token Preview:', authInfo.tokenPreview);
  console.log('Environment:', typeof window !== 'undefined' ? window.location.hostname : 'Server');
  console.groupEnd();
  return authInfo;
};

// Inicijaliziraj auth pri učitavanju
if (typeof window !== 'undefined') {
  // Dodaj malu odgodu da se osiguramo da je localStorage dostupan
  setTimeout(() => {
    const initialized = authHelper.initializeAuth();
    console.log('🔄 Auth initialization result:', initialized);
    
    // Testiraj API konekciju pri pokretanju (samo u developmentu)
    if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
      setTimeout(async () => {
        try {
          const connectionTest = await apiUtils.testConnection();
          console.log('🌐 Initial connection test:', connectionTest);
        } catch (error) {
          console.warn('⚠️ Initial connection test failed:', error.message);
        }
      }, 2000);
    }
  }, 100);
}

export default api;