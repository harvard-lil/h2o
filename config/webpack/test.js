process.env.NODE_ENV = process.env.NODE_ENV || 'development';

const environment = require('./environment');
let config = environment.toWebpackConfig();

// https://vue-test-utils.vuejs.org/guides/testing-single-file-components-with-mocha-webpack.html
// despite the vue-test-utils sample config recommending using nodeExternals, including it caused compile errors with vue.esm.js so it's been excluded here
let testOverrides = {
  devtool: 'inline-cheap-module-source-map',
  output: {
    // use absolute paths in sourcemaps (important for debugging via IDE)
    devtoolModuleFilenameTemplate: '[absolute-resource-path]',
    devtoolFallbackModuleFilenameTemplate: '[absolute-resource-path]?[hash]'
  }
};

// the default scss/sass rules cause mocha-webpack to choke
config.module.rules = config.module.rules
  .filter(r => !".scss".match(r.test))
  .concat([{
    test: /\.scss$/,
    use: [
      "style-loader", // creates style nodes from JS strings
      "css-loader", // translates CSS into CommonJS
      "sass-loader" // compiles Sass to CSS, using Node Sass by default
    ]}]);

module.exports = {...config, ...testOverrides};
