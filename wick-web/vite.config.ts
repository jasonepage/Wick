import { defineConfig } from "vite";

// base './' so a production build works when hosted under a subpath
// (e.g. GitHub Pages /wick/, keeping links on GitHub Pages per C5).
export default defineConfig({
  base: "./",
  server: { port: 5173 },
});
