import Vue from "vue/dist/vue.esm";
import VueRouter from 'vue-router';
Vue.use(VueRouter);
Vue.config.productionTip = process.env.NODE_ENV == "development";

import store from "../store/index";
import "../config/axios";
import "../directives/selectionchange";

import contenteditableDirective from "vue-contenteditable-directive";
Vue.use(contenteditableDirective);

import TheResource from "../components/TheResource";

document.addEventListener("DOMContentLoaded", () => {
  const routes = [
    { path: '/casebooks/:id/resources/:resource_id/', component: TheResourceBody}
  ];

  const router = new VueRouter({
    routes
  });

  const app = new Vue({
    el: "#app",
    store,
    router,
    components: {
      TheResource
    }
  });

  window.app = app;
});
