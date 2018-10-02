const { environment } = require('@rails/webpacker');
const webpack = require('webpack');
const { resolve } = require("path");

environment.plugins.append('Provide', new webpack.ProvidePlugin({
  $: 'jquery',
  jQuery: 'jquery'
}));

environment.loaders
  .get('sass')
  .use.find(item => item.loader === 'sass-loader').options.includePaths = [
    resolve("app", "assets", "stylesheets")
  ];

module.exports = environment;
