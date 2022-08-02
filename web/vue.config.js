const BundleTracker = require('webpack-bundle-tracker');
const path = require('path');
const webpack = require('webpack');

/*** helpers ***/

const devMode = process.env.NODE_ENV !== 'production';
const testMode = process.env.NODE_ENV === 'test'

// BundleTracker includes absolute paths, which causes webpack-stats.json to change when it shouldn't.
// We use this RelativeBundleTracker workaround via https://github.com/owais/webpack-bundle-tracker/issues/25
const RelativeBundleTracker = function(options) {
  BundleTracker.call(this, options);
};
RelativeBundleTracker.prototype = Object.create(BundleTracker.prototype);
RelativeBundleTracker.prototype.writeOutput = function(compiler, contents) {
  if(contents.chunks){
    const relativePathRoot = path.join(__dirname) + path.sep;
    for(const bundle of Object.values(contents.chunks)){
      for(const chunk of bundle){
        if (chunk.path.startsWith(relativePathRoot)) {
          chunk.path = chunk.path.substr(relativePathRoot.length);
        }
      }
    }
  }
  BundleTracker.prototype.writeOutput.call(this, compiler, contents);
};

/*** Vue config ***/
let devServerHost = process.env.DOCKERIZED ? '0.0.0.0' : '127.0.0.1';

let vueConfig = {
  outputDir: 'static/dist',

  // When running `npm run serve`, paths in webpack-stats.json will point to the live dev server.
  // Otherwise they will point to the compiled assets URL.
  publicPath: devMode ? 'http://localhost:8080/static/dist' : '/static/dist',

  pages: {
    application: 'frontend/pages/application.js',
    rich_text_editor: 'frontend/pages/rich_text_editor.js',
    main: 'frontend/pages/main.scss',
    test: 'frontend/pages/test.js',
    vue_app: 'frontend/pages/vue_app.js'
  },

  configureWebpack: {
    plugins: [
      new webpack.ProvidePlugin({
        $: 'jquery',
        jQuery: 'jquery'
      }),].concat(testMode ? [] : [
        new RelativeBundleTracker({
          // output location of bundles so they can be found by django
          filename: './webpack-stats.json'}),
      ]),
    resolve: {
      alias: {
        '@': path.resolve("frontend"),
        vue: "vue/dist/vue.esm.js",
        'vue$': 'vue/dist/vue.esm.js',
        // alias assets dir to ~assets for SASS url() styles
        static: path.resolve("static"),
      },
      modules: [
        path.resolve('frontend'),
        path.resolve('frontend', 'styles'),
        'node_modules'
      ],
    }
  },

  devServer: {
    public: devServerHost + ':8080',
    host: devServerHost,
    headers: { 'Access-Control-Allow-Origin': '*' },
    allowedHosts: [
	'.h2o-dev.local',
	'opencasebook.test',
    ],
  },

  chainWebpack: config => {
    // delete HTML related webpack plugins
    // via https://github.com/vuejs/vue-cli/issues/1478
    Object.keys(vueConfig.pages).forEach(function (key) {
      config.plugins.delete('html-' + key);
      config.plugins.delete('preload-' + key);
      config.plugins.delete('prefetch-' + key);
    });

    // use same chunks config for dev as prod so {% render_bundle %} works on both
    // copied from node_modules/@vue/cli-service/lib/config/app.js
    config.optimization.splitChunks({
      cacheGroups: {
        // vendors: {
        //   name: `chunk-vendors`,
        //   test: /[\\/]node_modules[\\/]/,
        //   priority: -10,
        //   chunks: 'initial'
        // },
        common: {
          name: `chunk-common`,
          minChunks: 2,
          priority: -20,
          chunks: 'initial',
          reuseExistingChunk: true
        }
      }
    });

    // workaround for "SASS files from NPM modules referencing relative imports won't build [in mocha]"
    // https://github.com/vuejs/vue-cli/issues/4053#issuecomment-544641072
    if (testMode) {
      const scssRule = config.module.rule('scss');
      scssRule.uses.clear();
      scssRule
        .use('null-loader')
        .loader('null-loader');
    }
  },

};

module.exports = vueConfig;
