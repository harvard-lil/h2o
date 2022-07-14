import Vue from "vue";
import VueRouter from 'vue-router';
import * as Sentry from "@sentry/vue";
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
import QuickAdd from "../components/QuickAdd";
import ResourceTypePicker from "../components/ResourceTypePicker";
import Globals from "../components/Globals";
import AuditButton from "../components/AuditButton";
import Dashboard from "../components/Dashboard";

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
        QuickAdd,
        ResourceTypePicker,
        Globals,
        AuditButton,
        Dashboard
    }
  });

  if (window.sentry.USE_SENTRY) {
    console.log('using sentry');
    Sentry.init({
      Vue,
      dsn: window.sentry.DSN,
      environment: window.sentry.ENVIRONMENT,

      // Set tracesSampleRate to 1.0 to capture 100%
      // of transactions for performance monitoring.
      // We recommend adjusting this value in production
      tracesSampleRate: window.sentry.TRACES_SAMPLE_RATE,
    });
  }

  window.app = app;
});
