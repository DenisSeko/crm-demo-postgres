<template>
  <div class="max-w-md mx-auto mt-20 p-6 bg-white rounded-lg shadow-md">
    <h2 class="text-2xl font-bold mb-6 text-center">Prijava</h2>
    <form @submit.prevent="$emit('login', loginData)" class="space-y-4">
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
        {{ isLoggingIn ? 'Prijavljujem...' : 'Prijavi se' }}
      </button>
    </form>
    
    <div class="mt-4 p-3 bg-yellow-50 rounded-md text-sm">
      <strong>Demo pristup:</strong><br>
      Email: demo@demo.com<br>
      Lozinka: demo123
    </div>

    <div class="mt-4 text-center">
      <a href="#" @click.prevent="$emit('go-home')" class="text-blue-600 hover:text-blue-800 text-sm">
        ← Povratak na početnu
      </a>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive } from 'vue'

defineProps({
  isLoggingIn: {
    type: Boolean,
    default: false
  }
})

defineEmits(['login', 'go-home'])

const loginData = reactive({
  email: 'demo@demo.com',
  password: 'demo123'
})
</script>
