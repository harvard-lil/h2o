import Vue from "vue";
import Vuex from "vuex";
import annotations from "./modules/annotations";
import annotations_ui from "./modules/annotations_ui";
import footnotes_ui from "./modules/footnotes_ui";
import resources_ui from "./modules/resources_ui";
import createLogger from "vuex/dist/logger";

Vue.use(Vuex);

const debug = process.env.NODE_ENV == "development";

export default new Vuex.Store({
  modules: {annotations,
            annotations_ui,
            footnotes_ui,
            resources_ui},
  strict: debug,
  plugins: debug ? [createLogger()] : []
});
