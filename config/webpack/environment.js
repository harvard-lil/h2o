const { environment } = require('@rails/webpacker');
const webpack = require('webpack');
const { resolve } = require("path");

// add the stylesheets directory to the sass loader so that @import's resolve
environment.loaders
  .get('sass')
  .use.find(item => item.loader === 'sass-loader').options.includePaths = [
    resolve("app", "assets", "stylesheets")
  ];

// allow img() paths in sass/css to be written relative to the sass file
environment.loaders.get('sass').use.splice(-1, 0, {
  loader: 'resolve-url-loader'
});

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

module.exports = environment;
