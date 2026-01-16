import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig(({ mode }) => {
  // Load env from backend folder
  const env = loadEnv(mode, path.resolve(__dirname, '../backend'), '')

  return {
    plugins: [react()],
    server: {
      port: 5173
    },
    define: {
      'import.meta.env.VITE_SUPABASE_URL': JSON.stringify(env.SUPABASE_URL),
      'import.meta.env.VITE_SUPABASE_ANON_KEY': JSON.stringify(env.SUPABASE_ANON_KEY),
      'import.meta.env.VITE_API_URL': JSON.stringify(env.API_URL || 'http://localhost:3000/api'),
    }
  }
})

