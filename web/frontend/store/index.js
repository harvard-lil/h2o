import Vue from "vue";
import Vuex from "vuex";
import annotations from "./modules/annotations";
import annotations_ui from "./modules/annotations_ui";
import footnotes_ui from "./modules/footnotes_ui";
import resources_ui from "./modules/resources_ui";
import table_of_contents from "./modules/table_of_contents";
import createLogger from "vuex/dist/logger";
import case_search from './modules/case_search';

Vue.use(Vuex);

const debug = process.env.NODE_ENV == "development";

export default new Vuex.Store({
  modules: {annotations,
            annotations_ui,
            footnotes_ui,
            resources_ui,
            table_of_contents,
            case_search},
  strict: debug,
  plugins: debug ? [createLogger()] : []
});
