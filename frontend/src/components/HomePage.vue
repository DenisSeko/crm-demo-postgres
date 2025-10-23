<template>
  <div class="max-w-3xl mx-auto mt-20 p-6 bg-white rounded-lg shadow-md text-center">
    <h2 class="text-3xl font-bold mb-6">Dobrodošli u CRM Demo!</h2>
    <p class="text-gray-700 mb-8">
      Ovaj demo prikazuje osnovne funkcionalnosti CRM sustava s Vue 3, Node.js i PostgreSQL (port 5433).
    </p>
    <button @click="$emit('go-to-login')"
      class="bg-blue-600 text-white py-3 px-6 rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500">
      Idi na prijavu
    </button>
    
    <div class="mt-8 grid grid-cols-1 md:grid-cols-3 gap-4 text-left">
      <div class="p-4 bg-blue-50 rounded-lg">
        <h3 class="font-semibold text-blue-800">📊 Dashboard</h3>
        <p class="text-sm text-blue-600 mt-2">Pregled klijenata i statistika</p>
      </div>
      <div class="p-4 bg-green-50 rounded-lg">
        <h3 class="font-semibold text-green-800">👥 Klijenti</h3>
        <p class="text-sm text-green-600 mt-2">Upravljanje klijentima i bilješkama</p>
      </div>
      <div class="p-4 bg-purple-50 rounded-lg">
        <h3 class="font-semibold text-purple-800">🗄️ Baza</h3>
        <p class="text-sm text-purple-600 mt-2">PostgreSQL na portu 5433</p>
      </div>
    </div>
  </div>
</template>

<script setup>
defineEmits(['go-to-login'])
</script>
