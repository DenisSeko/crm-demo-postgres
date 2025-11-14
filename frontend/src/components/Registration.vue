<template>
  <div class="max-w-md mx-auto mt-10 p-6 bg-white rounded-lg shadow-md">
    <h2 class="text-2xl font-bold mb-6 text-center">Registracija</h2>
    
    <div v-if="message" :class="['mb-4 p-3 rounded-md text-sm', messageType === 'success' ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700']">
      {{ message }}
    </div>

    <form @submit.prevent="handleRegister" class="space-y-4">
      <div class="grid grid-cols-2 gap-4">
        <div>
          <label for="firstName" class="block text-sm font-medium text-gray-700">Ime *</label>
          <input 
            id="firstName"
            name="firstName"
            v-model="registerData.firstName" 
            type="text"
            autocomplete="given-name"
            class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            required
          >
        </div>
        <div>
          <label for="lastName" class="block text-sm font-medium text-gray-700">Prezime *</label>
          <input 
            id="lastName"
            name="lastName"
            v-model="registerData.lastName" 
            type="text"
            autocomplete="family-name"
            class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            required
          >
        </div>
      </div>

      <div>
        <label for="username" class="block text-sm font-medium text-gray-700">Korisničko ime *</label>
        <input 
          id="username"
          name="username"
          v-model="registerData.username" 
          type="text"
          autocomplete="username"
          class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          required
        >
        <p class="text-xs text-gray-500 mt-1">Korisničko ime mora biti jedinstveno</p>
      </div>

      <div>
        <label for="email" class="block text-sm font-medium text-gray-700">Email *</label>
        <input 
          id="email"
          name="email"
          v-model="registerData.email" 
          type="email"
          autocomplete="email"
          class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          required
        >
      </div>

      <div>
        <label for="password" class="block text-sm font-medium text-gray-700">Lozinka *</label>
        <input 
          id="password"
          name="password"
          v-model="registerData.password" 
          type="password"
          autocomplete="new-password"
          class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          required
          minlength="6"
        >
        <p class="text-xs text-gray-500 mt-1">Lozinka mora imati najmanje 6 znakova</p>
      </div>

      <div>
        <label for="confirmPassword" class="block text-sm font-medium text-gray-700">Potvrdi lozinku *</label>
        <input 
          id="confirmPassword"
          name="confirmPassword"
          v-model="registerData.confirmPassword" 
          type="password"
          autocomplete="new-password"
          class="mt-1 block w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          required
        >
      </div>

      <button 
        type="submit"
        class="w-full bg-green-600 text-white py-2 px-4 rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 flex items-center justify-center transition-all duration-200"
        :disabled="isRegistering || !isFormValid"
      >
        <span v-if="isRegistering" class="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></span>
        {{ isRegistering ? 'Registriram...' : 'Registriraj se' }}
      </button>
    </form>

    <div class="mt-6 p-4 bg-blue-50 rounded-md text-sm">
      <h3 class="font-semibold mb-2">📋 Demo korisnici (već postoje u sustavu):</h3>
      <div class="space-y-1 text-xs">
        <div><strong>Admin:</strong> admin@crm.com / password123</div>
        <div><strong>Ivan Horvat:</strong> ivan.horvat@primjer.hr / password123</div>
        <div><strong>Ana Kovač:</strong> ana.kovac@primjer.hr / password123</div>
        <div><strong>Marko Petrov:</strong> marko.petrov@primjer.hr / password123</div>
      </div>
    </div>

    <div class="mt-4 text-center space-y-2">
      <p class="text-sm text-gray-600">
        Već imate račun?
        <a href="#" @click.prevent="$emit('show-login')" class="text-blue-600 hover:text-blue-800 font-medium transition-colors duration-200">
          Prijavite se ovdje
        </a>
      </p>
      <a href="#" @click.prevent="$emit('go-home')" class="text-blue-600 hover:text-blue-800 text-sm block transition-colors duration-200">
        ← Povratak na početnu
      </a>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed } from 'vue'
import api from '../services/api'

const emit = defineEmits(['show-login', 'go-home', 'registered'])

const isRegistering = ref(false)
const message = ref('')
const messageType = ref('') // 'success' ili 'error'

const registerData = reactive({
  firstName: '',
  lastName: '',
  username: '',
  email: '',
  password: '',
  confirmPassword: ''
})

// Validacija forme
const isFormValid = computed(() => {
  return (
    registerData.firstName.trim() &&
    registerData.lastName.trim() &&
    registerData.username.trim() &&
    registerData.email.trim() &&
    registerData.password.length >= 6 &&
    registerData.password === registerData.confirmPassword
  )
})

const showMessage = (text, type) => {
  message.value = text
  messageType.value = type
  setTimeout(() => {
    message.value = ''
    messageType.value = ''
  }, 5000)
}

const handleRegister = async () => {
  if (!isFormValid.value) {
    showMessage('Molimo ispunite sva polja ispravno.', 'error')
    return
  }

  if (registerData.password !== registerData.confirmPassword) {
    showMessage('Lozinke se ne podudaraju.', 'error')
    return
  }

  isRegistering.value = true
  message.value = ''

  try {
    const response = await api.post('/auth/register', {
      firstName: registerData.firstName,
      lastName: registerData.lastName,
      username: registerData.username,
      email: registerData.email,
      password: registerData.password
    })

    showMessage('Uspješno ste registrirani! Možete se prijaviti.', 'success')
    
    // Reset forma
    Object.assign(registerData, {
      firstName: '',
      lastName: '',
      username: '',
      email: '',
      password: '',
      confirmPassword: ''
    })

    // Emit event da je korisnik registriran
    emit('registered', response.data)

    // Prebaci na login nakon 2 sekunde
    setTimeout(() => {
      emit('show-login')
    }, 2000)

  } catch (error) {
    console.error('Registration error:', error)
    
    const errorMessage = error.response?.data?.error || 
                        error.response?.data?.message || 
                        'Došlo je do greške pri registraciji. Pokušajte ponovno.'
    
    showMessage(errorMessage, 'error')
  } finally {
    isRegistering.value = false
  }
}
</script>

<style scoped>
input:focus {
  transform: translateY(-1px);
  box-shadow: 0 4px 6px -1px rgba(59, 130, 246, 0.1), 0 2px 4px -1px rgba(59, 130, 246, 0.06);
}

button:not(:disabled):hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(34, 197, 94, 0.3);
}
</style>