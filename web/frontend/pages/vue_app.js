import "../config/axios";
import "../directives/selectionchange";

import * as Sentry from "@sentry/vue";
import { beforeSend } from "../config/sentry";

import AddContent from "../components/AddContent";
import AuditButton from "../components/AuditButton";
import Dashboard from "../components/Dashboard";
import Globals from "../components/Globals";
import LegalDocumentSearch from "../components/LegalDocumentSearch/LegalDocumentSearch";
import QuickAdd from "../components/QuickAdd";
import SectionCloner from "../components/SectionCloner";
import TakeNotesCloner from "../components/TakeNotesCloner";
import TheResource from "../components/TheResource";
import TheTableOfContents from "../components/TheTableOfContents";
import Vue from "vue";
import { componentApps } from "../libs/mount_components";
import { createRouter, createWebHistory } from 'vue-router';
import contenteditableDirective from "vue-contenteditable-directive";
import store from "../store/index";


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

  const router = createRouter({
      routes,
      history: createWebHistory()
  });

  const mounts = componentApps(document.getElementById('app'), {
    'globals': Globals,
    'add-content': AddContent,
    'audit-button': AuditButton,
    'dashboard': Dashboard,
    'legal-document-search': LegalDocumentSearch,
    'quick-add': QuickAdd,
    'section-cloner': SectionCloner,
    'take-notes-cloner': TakeNotesCloner,
    'the-resource': TheResource,
    'the-table-of-contents': TheTableOfContents,
  });
  if (window.sentry.USE_SENTRY) {
    console.log('using sentry');
    Sentry.init({
      app: mounts.map(({app}) => app),
      dsn: window.sentry.DSN,
      environment: window.sentry.ENVIRONMENT,
      release: import.meta.env.H2O_RELEASE || undefined,
      beforeSend,
      integrations: [
        Sentry.browserTracingIntegration({ router }),
      ],
      // Set tracesSampleRate to 1.0 to capture 100%
      // of transactions for performance monitoring.
      // We recommend adjusting this value in production
      tracesSampleRate: window.sentry.TRACES_SAMPLE_RATE,
    });
  }

  // The legacy export dialog reads only $store from this compatibility handle.
  window.app = {$store: store};
  for (const {app, element} of mounts) {
    app.use(store);
    app.use(router);
    element.style.display = 'contents';
    app.mount(element);
  }
});
