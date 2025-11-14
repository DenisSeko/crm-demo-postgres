<template>
  <div class="fixed inset-0 bg-white bg-opacity-95 z-50 flex items-center justify-center transition-opacity duration-300">
    <div class="text-center">
      <!-- Animated spinner -->
      <div class="animate-spin rounded-full h-16 w-16 border-b-2 border-blue-600 mx-auto mb-4"></div>
      
      <!-- Loading text -->
      <p class="text-gray-700 font-semibold text-lg mb-2">{{ message }}</p>
      <p class="text-gray-500 text-sm">{{ subMessage }}</p>
      
      <!-- Optional progress dots -->
      <div class="flex justify-center space-x-1 mt-4">
        <div class="w-2 h-2 bg-blue-600 rounded-full animate-pulse" style="animation-delay: 0ms"></div>
        <div class="w-2 h-2 bg-blue-600 rounded-full animate-pulse" style="animation-delay: 200ms"></div>
        <div class="w-2 h-2 bg-blue-600 rounded-full animate-pulse" style="animation-delay: 400ms"></div>
      </div>
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

<style scoped>
/* Smooth fade-in animation */
.fade-enter-active {
  transition: opacity 0.3s ease;
}
.fade-enter-from {
  opacity: 0;
}
</style>
