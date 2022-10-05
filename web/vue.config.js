const BundleTracker = require("webpack-bundle-tracker");
const path = require("path");
const webpack = require("webpack");

/*** helpers ***/

const devMode = process.env.NODE_ENV !== "production";
const testMode = process.env.NODE_ENV === "test";


/*** Vue config ***/
let devServerHost = process.env.DOCKERIZED ? "0.0.0.0" : "127.0.0.1";

let vueConfig = {
  outputDir: "static/dist",

  // When running `npm run serve`, paths in webpack-stats.json will point to the live dev server.
  // Otherwise they will point to the compiled assets URL.
  publicPath: devMode ? "http://localhost:8080/static/dist" : "/static/dist",

  pages: {
    application: "frontend/pages/application.js",
    rich_text_editor: "frontend/pages/rich_text_editor.js",
    main: "frontend/pages/main.scss",
    test: "frontend/pages/test.js",
    vue_app: "frontend/pages/vue_app.js",
    as_printable_html_styles: "frontend/pages/as_printable_html.scss",
    as_printable_html: "frontend/pages/as_printable_html.js",
  },

  configureWebpack: {
    plugins: [
      new webpack.ProvidePlugin({
        $: "jquery",
        jQuery: "jquery",
      }),
    ].concat(
      testMode
        ? []
        : [
            new BundleTracker({
              // output location of bundles so they can be found by django
              filename: "./webpack-stats.json",
              relativePath: true
            }),
          ]
    ),
    resolve: {
      alias: {
        "@": path.resolve("frontend"),
        vue: "vue/dist/vue.esm.js",
        vue$: "vue/dist/vue.esm.js",
        // alias assets dir to ~assets for SASS url() styles
        static: path.resolve("static"),
      },
      modules: [
        path.resolve("frontend"),
        path.resolve("frontend", "styles"),
        "node_modules",
      ],
    },
  },

  devServer: {
    public: devServerHost + ":8080",
    host: devServerHost,
    headers: { "Access-Control-Allow-Origin": "*" },
    allowedHosts: [".h2o-dev.local", "opencasebook.test"],
  },

  chainWebpack: (config) => {
    // delete HTML related webpack plugins
    // via https://github.com/vuejs/vue-cli/issues/1478
    Object.keys(vueConfig.pages).forEach(function (key) {
      config.plugins.delete("html-" + key);
      config.plugins.delete("preload-" + key);
      config.plugins.delete("prefetch-" + key);
    });

    // workaround for "SASS files from NPM modules referencing relative imports won't build [in mocha]"
    // https://github.com/vuejs/vue-cli/issues/4053#issuecomment-544641072
    if (testMode) {
      const scssRule = config.module.rule("scss");
      scssRule.uses.clear();
      scssRule.use("null-loader").loader("null-loader");
    }
  },
};

module.exports = vueConfig;
