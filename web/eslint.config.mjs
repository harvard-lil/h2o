import js from "@eslint/js";
import vue from "eslint-plugin-vue";
import globals from "globals";

export default [
  js.configs.recommended,
  ...vue.configs["flat/essential"],
  {
    files: ["frontend/**/*.{js,vue}"],
    languageOptions: {
      globals: {
        ...globals.browser,
        ...globals.node,
        FRONTEND_URLS: "readonly",
        $: "readonly",
        jQuery: "readonly",
        app: "readonly",
        CKEDITOR: "readonly",
      },
    },
    rules: {
      "no-cond-assign": "off",
      "vue/multi-word-component-names": "off",
      "no-unused-vars": ["error", { args: "none", ignoreRestSiblings: true, varsIgnorePattern: "^_" }],
    },
  },
  {
    files: ["frontend/test/**/*.js"],
    languageOptions: { globals: { ...globals.vitest } },
  },
];
