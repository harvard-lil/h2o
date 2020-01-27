import Vue from "vue";
Vue.config.productionTip = process.env.NODE_ENV == "development";

import store from "../store/index";
import "../config/axios";

import TheTableOfContents from "../components/TheTableOfContents";

document.addEventListener("DOMContentLoaded", () => {
    const el = document.getElementById("table-of-contents");
    const app = new Vue({
        el,
        store,
        components: {
            TheTableOfContents
        }
    });

    window.app = app;
});
