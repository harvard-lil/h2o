module.exports = {
  test: /\.vue(\.erb)?$/,
  use: [{
    loader: 'vue-loader',
    options: {
      compilerOptions: {
        // Enabled to prevent annotations from incurring incorrect
        // offsets due to extra whitespace in templates
        whitespace: 'condense'
      }
    }
  }]
};
