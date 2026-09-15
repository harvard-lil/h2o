import Vue, { createApp } from "vue";
import { createRouter, createWebHistory } from 'vue-router';

Vue.config.productionTip = process.env.NODE_ENV == "development";

import store from "../store/index";
import "../config/axios";

import TheTableOfContents from "../components/TheTableOfContents";

document.addEventListener("DOMContentLoaded", () => {
    const routes = [
        { path: '/casebooks/:casebook_id/section/:section_id/', component: TheTableOfContents },
        { path: '/casebooks/:casebook_id/resource/:section_id/', component: TheTableOfContents },
        { path: '/casebooks/:casebook_id/', component: TheTableOfContents }

    ];

    const router = createRouter({
        routes,
        scrollBehavior: function(to, from, savedPosition) {
            if (to.hash) {
                return {selector: to.hash};
            } else {
                return { x: 0, y: 0 };
            }
        },
        history: createWebHistory()
    });

    const el = document.getElementById("table-of-contents");
    const app = createApp({
                components: {
            TheTableOfContents
        }
    });

    app.use(store);
  app.use(router);
  window.app = app.mount(el);
});
