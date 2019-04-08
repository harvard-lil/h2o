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
  const routes = [
    { path: '/casebooks/:id/resources/:resource_id/annotate', component: TheResourceBody} 
  ];

  const router = new VueRouter({
    routes
  });

  new Vue({
    store,
    router,
    components: {
      TheResourceBody
    }
  }).$mount('#app');
});
