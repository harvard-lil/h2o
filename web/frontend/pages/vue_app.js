import "../config/axios";
import "../directives/selectionchange";

import * as Sentry from "@sentry/vue";
import { BrowserTracing } from "@sentry/tracing";

import AddContent from "../components/AddContent";
import AuditButton from "../components/AuditButton";
import Dashboard from "../components/Dashboard";
import ExportButton from "../components/ExportButton";
import Globals from "../components/Globals";
import LegalDocumentSearch from "../components/LegalDocumentSearch/LegalDocumentSearch";
import PortalVue from "portal-vue";
import QuickAdd from "../components/QuickAdd";
import SectionCloner from "../components/SectionCloner";
import TakeNotesCloner from "../components/TakeNotesCloner";
import TheResource from "../components/TheResource";
import TheTableOfContents from "../components/TheTableOfContents";
import Vue from "vue";
import VueRouter from 'vue-router';
import contenteditableDirective from "vue-contenteditable-directive";
import store from "../store/index";

Vue.use(VueRouter);
Vue.config.productionTip = process.env.NODE_ENV == "development";


Vue.use(contenteditableDirective);


// Font Awesome
import { library } from '@fortawesome/fontawesome-svg-core'
import { faCheck, faXmark } from '@fortawesome/free-solid-svg-icons'
import { FontAwesomeIcon } from '@fortawesome/vue-fontawesome'

library.add(faCheck, faXmark)
Vue.component('font-awesome-icon', FontAwesomeIcon)

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
        AddContent,
        AuditButton,
        Dashboard,
        ExportButton,
        Globals,
        LegalDocumentSearch,
        PortalVue,
        QuickAdd,
        SectionCloner,
        TakeNotesCloner,
        TheResource,
        TheTableOfContents,
    }
  });
  if (window.sentry.USE_SENTRY) {
    console.log('using sentry');
    Sentry.init({
      Vue,
      dsn: window.sentry.DSN,
      environment: window.sentry.ENVIRONMENT,
      integrations: [
        new BrowserTracing({
          routingInstrumentation: Sentry.vueRouterInstrumentation(router),
          tracePropagationTargets: ["opencasebook.org", "opencasebook.test", /^\//],
        }),
      ],
      // Set tracesSampleRate to 1.0 to capture 100%
      // of transactions for performance monitoring.
      // We recommend adjusting this value in production
      tracesSampleRate: window.sentry.TRACES_SAMPLE_RATE,
    });
  }

  window.app = app;
});
