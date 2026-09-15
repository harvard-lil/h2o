import { createStore, createLogger } from "vuex";
import annotations from "./modules/annotations";
import annotations_ui from "./modules/annotations_ui";
import footnotes_ui from "./modules/footnotes_ui";
import resources_ui from "./modules/resources_ui";
import table_of_contents from "./modules/table_of_contents";
import case_search from './modules/case_search';
import globals from './modules/globals';


const debug = process.env.NODE_ENV == "development";

export default createStore({
  modules: {
    annotations,
    annotations_ui,
    footnotes_ui,
    resources_ui,
    table_of_contents,
    case_search,
    globals
  },
  strict: debug,
  plugins: debug ? [createLogger()] : []
});
