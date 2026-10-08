import path from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Change this to your EC2 URL if it moves. Use the Elastic IP.
const API = "http://35.181.195.127:8000";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  server: {
    port: 5173,
    proxy: {
      "/auth":   { target: API, changeOrigin: true },
      "/events": { target: API, changeOrigin: true },
      "/stats":  { target: API, changeOrigin: true },
      "/alerts": { target: API, changeOrigin: true },
      "/health": { target: API, changeOrigin: true },
    },
  },
  build: {
    outDir: "dist",
    sourcemap: false,
  },
});