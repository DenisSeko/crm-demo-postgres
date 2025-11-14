<template>
  <nav class="bg-white shadow-sm border-b">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex justify-between items-center h-16">
        <!-- Logo i naslov -->
        <div class="flex items-center">
          <a href="#" @click.prevent="$emit('go-home')" 
             class="flex items-center space-x-3 text-gray-800 hover:text-blue-600 transition-colors duration-200">
            <div class="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center">
              <span class="text-white font-bold text-sm">CRM</span>
            </div>
            <h1 class="text-xl font-semibold hidden sm:block">
              CRM Sustav
            </h1>
          </a>
        </div>

        <!-- User info ili status -->
        <div class="flex items-center space-x-4">
          <template v-if="user">
            <!-- User info -->
            <div class="flex items-center space-x-3 bg-gray-50 rounded-lg px-3 py-2">
              <div class="w-8 h-8 bg-blue-600 rounded-full flex items-center justify-center text-white font-semibold text-sm">
                {{ getUserInitials(user) }}
              </div>
              <div class="hidden md:block">
                <div class="text-sm font-medium text-gray-700">{{ user.firstName }} {{ user.lastName }}</div>
                <div class="text-xs text-gray-500 capitalize">{{ user.role }}</div>
              </div>
            </div>
            
            <!-- Logout button -->
            <button @click="$emit('logout')"
                    class="text-gray-600 hover:text-red-600 px-3 py-2 rounded-md text-sm font-medium flex items-center gap-2 transition-colors duration-200 hover:bg-red-50 border border-transparent hover:border-red-200">
              <span class="text-lg">🚪</span>
              <span class="hidden sm:inline">Odjava</span>
            </button>
          </template>
          
          <template v-else>
            <!-- Status indicator kada nema prijavljenog korisnika -->
            <div class="flex items-center space-x-2 text-sm text-gray-500">
              <div class="w-2 h-2 bg-gray-400 rounded-full animate-pulse"></div>
              <span class="hidden sm:inline">Niste prijavljeni</span>
            </div>
            
            <!-- Home button -->
            <button @click="$emit('go-home')"
                    class="text-blue-600 hover:text-blue-800 px-3 py-2 rounded-md text-sm font-medium flex items-center gap-2 transition-colors duration-200 hover:bg-blue-50">
              <span class="text-lg">🏠</span>
              <span class="hidden sm:inline">Početna</span>
            </button>
          </template>
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

// Helper funkcija za dobivanje inicijala korisnika
const getUserInitials = (user) => {
  if (!user) return '?'
  const first = user.firstName?.charAt(0) || ''
  const last = user.lastName?.charAt(0) || ''
  return (first + last).toUpperCase() || user.username?.charAt(0)?.toUpperCase() || 'U'
}
</script>

<style scoped>
/* Smooth transitions */
nav {
  transition: all 0.3s ease;
}

/* Hover effects */
button:hover {
  transform: translateY(-1px);
  transition: transform 0.2s ease;
}
</style>