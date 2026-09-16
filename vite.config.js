import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3100,
    // Proxy API calls to the backend so there are zero CORS issues in the browser
    proxy: {
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true,
      },
      // Proxy /uploads so document images stored as relative paths
      // (/uploads/documents/file.jpg) load correctly in the admin portal
      // regardless of which host the mobile app used during upload.
      '/uploads': {
        target: 'http://localhost:3000',
        changeOrigin: true,
      },
    },
  },
})
