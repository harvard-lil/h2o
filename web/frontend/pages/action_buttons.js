import Vue from "vue";
Vue.config.productionTip = process.env.NODE_ENV == "development";

import store from "../store/index";
import "../config/axios";

import SectionCloner from "../components/SectionCloner";

document.addEventListener("DOMContentLoaded", () => {
    const el = document.getElementById("action-buttons");
    const app = new Vue({
        el,
        store,
        components: {
            SectionCloner
        }
    });

    window.app = app;
});
