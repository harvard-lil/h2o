import Vue from "vue/dist/vue.esm";
import VueRouter from 'vue-router';
Vue.config.productionTip = process.env.NODE_ENV == "development";
Vue.use(VueRouter);

import store from "../store/index";
import "../config/axios";
import "../directives/selectionchange";

import contenteditableDirective from "vue-contenteditable-directive";
Vue.use(contenteditableDirective);

import TheResourceBody from "../components/TheResourceBody";

document.addEventListener("DOMContentLoaded", () => {
  const routes = [];

  const router = new VueRouter({
    routes
  });

  const app = new Vue({
    el: "#app",
    store,
    router,
    components: {
      TheResourceBody
    }
  });

  window.app = app;
});
