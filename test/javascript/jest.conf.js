module.exports = {
  setupFiles: ["<rootDir>/jsdom_polyfills"],
  moduleFileExtensions: [
    "js",
    "json",
    "vue"
  ],
  moduleNameMapper: {
    "^@/(.*)$": "<rootDir>/src/$1",
  },
  "moduleDirectories": [
    "node_modules",
    "app/webpacker"
  ],
  transform: {
    "^.+\\.js$": "babel-jest",
    ".*\\.(vue)$": "vue-jest"
  },
  transformIgnorePatterns: ["<rootDir>/node_modules/"]
};
