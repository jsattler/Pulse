// @ts-check
import { defineConfig } from "astro/config";

import svelte from "@astrojs/svelte";

import sitemap from "@astrojs/sitemap";

import tailwindcss from "@tailwindcss/vite";

// https://astro.build/config
export default defineConfig({
  site: "https://jsattler.github.io",
  base: "/Pulse",
  integrations: [svelte(), sitemap()],

  vite: {
    plugins: [tailwindcss()],
  },
});

