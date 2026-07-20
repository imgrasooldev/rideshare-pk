import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Served by the backend at /admin (ServeStaticModule).
export default defineConfig({
  base: '/admin/',
  plugins: [react()],
})
