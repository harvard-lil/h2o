import Vue from "vue";
import VueRouter from 'vue-router';
Vue.use(VueRouter);
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

    const router = new VueRouter({
        routes,
        scrollBehavior: function(to, from, savedPosition) {
            if (to.hash) {
                return {selector: to.hash};
            } else {
                return { x: 0, y: 0 };
            }
        },
        mode: 'history'
    });

    const el = document.getElementById("table-of-contents");
    const app = new Vue({
        el,
        store,
        router,
        components: {
            TheTableOfContents
        }
    });

    window.app = app;
});
