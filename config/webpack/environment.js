const { environment } = require('@rails/webpacker');
const webpack = require('webpack');
const { resolve } = require("path");
const vue = require('./loaders/vue');

// alias assets dir to ~assets for SASS url() styles
environment.config.merge({resolve: {alias: {assets: resolve("app", "assets")}}});

// add the stylesheets directory to the sass loader so that @import's resolve
environment.loaders
  .get('sass')
  .use.find(item => item.loader === 'sass-loader').options.includePaths = [
    resolve("app", "assets", "stylesheets")
  ];

// parse erb files
environment.loaders.append('erb', {
  test: /\.erb$/,
  enforce: 'pre',
  use: [{loader: 'rails-erb-loader'}]
});

environment.plugins.append('Provide', new webpack.ProvidePlugin({
  $: 'jquery',
  jQuery: 'jquery'
}));

environment.loaders.append('vue', vue);
module.exports = environment;
