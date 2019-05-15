const { environment } = require('@rails/webpacker');
const webpack = require('webpack');
const { resolve } = require("path");
const vue = require('./loaders/vue');
const VueLoaderPlugin = require('vue-loader/lib/plugin');


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

// Uncomment to suppress output except on error.
// See https://github.com/harvard-lil/h2o/issues/743
//environment.config.stats = 'errors-only'

// Don't redirect anywhere on 404: return 404!
environment.config.merge({devServer: {historyApiFallback: false}});

environment.loaders.append('vue', vue);
environment.plugins.append('vue-loader', new VueLoaderPlugin());
module.exports = environment;
