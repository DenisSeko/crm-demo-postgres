<template>
  <nav class="bg-white shadow-sm border-b">
    <div class="max-w-6xl mx-auto px-4 py-3">
      <h1 class="text-xl font-semibold">
        <a href="#" @click.prevent="$emit('go-home')" class="text-blue-600 hover:text-blue-800">
          CRM Demo - PostgreSQL (Port 5433)
        </a>
      </h1>
      <div class="flex justify-between items-center">
        <div v-if="user" class="text-sm text-gray-600">
          Prijavljeni ste kao: {{ user.name }}
          <button @click="$emit('logout')" class="ml-4 text-red-600 hover:text-red-800">
            Odjava
          </button>
        </div>
        <div class="text-xs text-green-600 font-semibold">
          🗄️ PostgreSQL (5433)
        </div>
      </div>
    </div>
  </nav>
</template>

<script setup>
defineProps({
  user: {
    type: Object,
    default: null
  }
})

defineEmits(['go-home', 'logout'])
</script>
