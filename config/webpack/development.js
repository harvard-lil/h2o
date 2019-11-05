process.env.NODE_ENV = process.env.NODE_ENV || 'development'

const environment = require('./environment')

// These changes make development easier during this in-between
// time where we are running in Rails and Django simultaneously:
// the Django setup wants assets on disk, not in memory, and wants
// them to have reliable names.

// Write assets to disk, don't store in memory
environment.config.merge({devServer: {writeToDisk: true}});
// Don't use hashes in development
environment.config.merge({output: {filename: 'js/[name].js'}});
environment.plugins.get('MiniCssExtract').options.filename = 'css/[name].css';

module.exports = environment.toWebpackConfig()
