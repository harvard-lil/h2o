import Vue from "vue";
import VueRouter from 'vue-router';
Vue.use(VueRouter);
Vue.config.productionTip = process.env.NODE_ENV == "development";

import store from "../store/index";
import "../config/axios";
import "../directives/selectionchange";

import contenteditableDirective from "vue-contenteditable-directive";
Vue.use(contenteditableDirective);

import TheResource from "../components/TheResource";
import SectionCloner from "../components/SectionCloner";
import AddContent from "../components/AddContent";
import TheTableOfContents from "../components/TheTableOfContents";
import PortalVue from "portal-vue";
import CasebookOutliner from "../components/CasebookOutliner";
import ResourceTypePicker from "../components/ResourceTypePicker";

document.addEventListener("DOMContentLoaded", () => {
  const routes = [
    { path: '/casebooks/:id/resources/:resource_id/', component: TheResource }
  ];

  const router = new VueRouter({
      routes,
      mode: 'history'
  });

  const app = new Vue({
    el: "#app",
    store,
    router,
    components: {
        TheResource,
        SectionCloner,
        AddContent,
        TheTableOfContents,
        PortalVue,
        CasebookOutliner,
        ResourceTypePicker
    }
  });

  window.app = app;
});
