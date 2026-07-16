import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  // Change this if the GitHub repository name differs from target-marker-lab.
  base: process.env.GITHUB_ACTIONS ? '/target-marker-lab/' : '/',
  plugins: [vue()]
})
