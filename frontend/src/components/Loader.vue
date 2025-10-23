<template>
  <div class="fixed inset-0 bg-white z-50 flex items-center justify-center">
    <div class="text-center">
      <div class="animate-spin rounded-full h-16 w-16 border-b-2 border-blue-600 mx-auto mb-4"></div>
      <p class="text-gray-600 text-lg">{{ message }}</p>
      <p class="text-gray-400 text-sm">{{ subMessage }}</p>
    </div>
  </div>
</template>

<script setup>
defineProps({
  message: {
    type: String,
    default: 'Učitavanje...'
  },
  subMessage: {
    type: String,
    default: 'Prijavljujemo vas u sustav'
  }
})
</script>
