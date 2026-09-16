import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import { fileURLToPath } from "node:url";

const resolve = (path) => fileURLToPath(new URL(path, import.meta.url));

export default defineConfig({
  base: "/static/dist/",
  publicDir: false,
  plugins: [vue({ template: { compilerOptions: { compatConfig: { MODE: 2 } } } })],
  resolve: {
    alias: {
      vue: "@vue/compat/dist/vue.esm-bundler.js",
      "@vue/test-utils": resolve("./node_modules/@vue/test-utils/dist/vue-test-utils.esm-bundler.mjs"),
      "@": resolve("./frontend"),
      legacy: resolve("./frontend/legacy"),
      libs: resolve("./frontend/libs"),
      components: resolve("./frontend/components"),
      store: resolve("./frontend/store"),
      styles: resolve("./frontend/styles"),
      static: resolve("./static"),
    },
    extensions: [".mjs", ".js", ".json", ".vue"],
  },
  define: {
    "import.meta.env.H2O_RELEASE": JSON.stringify(process.env.H2O_RELEASE || ""),
    "process.env.NODE_ENV": JSON.stringify(process.env.NODE_ENV || "development"),
    global: "globalThis",
    __VUE_OPTIONS_API__: true,
    __VUE_PROD_DEVTOOLS__: false,
    __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: false,
  },
  css: {
    preprocessorOptions: {
      scss: { loadPaths: [resolve("./frontend"), resolve("./frontend/styles"), resolve("./node_modules")] },
    },
  },
  server: {
    port: 8080,
    strictPort: true,
    origin: "http://localhost:8080",
    cors: { origin: /^http:\/\/(localhost|127\.0\.0\.1|opencasebook\.test)(:\d+)?$/ },
    allowedHosts: ["opencasebook.test", ".h2o-dev.local"],
  },
  build: {
    outDir: "static/dist",
    manifest: "manifest.json",
    rollupOptions: {
      input: Object.fromEntries(
        ["application", "rich_text_editor", "main", "test", "vue_app"].map(
          (name) => [name, resolve(`./frontend/pages/${name}.js`)],
        ),
      ),
    },
  },
  test: {
    server: { deps: { inline: [/@vue\//, /vuex/] } },
    globals: true,
    environment: "jsdom",
    include: ["frontend/test/**/*.test.js"],
    setupFiles: ["./frontend/test/setup.js"],
  },
});
