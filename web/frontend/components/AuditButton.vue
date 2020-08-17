<template>
  <div id="audit-flow">
    <publish-button v-if="allNodesSpecified"></publish-button>
    <button class="action audit-casebook" v-on:click.stop.prevent="startAudit()" v-else>Finalize entries</button>
  </div>
</template>

<script>
import _ from "lodash";
import pp from "../libs/text_outline_parser";
import PublishButton from "./PublishButton";
import Axios from "../config/axios";
import urls from "../libs/urls";


export default {
  components: {
    PublishButton
  },
  data: () => ({autoAudited: {}}),
  methods: {
    bulkAddUrl: urls.url('new_from_outline'),    
    startAudit: function() {
      let self = this;
      function slowSearches(nodes) {
        let closedNodes = _.reverse(nodes.slice());
        const delay = 250;
        function popAndSearch() {
          let node = closedNodes.pop();
          if (!node) return;
          if (_.has(node, "title")) {
            let query = pp.extractCaseSearch(node.title);
            self.$store.dispatch("case_search/fetch", { query });
          }
          setTimeout(popAndSearch,delay);
        }
        popAndSearch();
      }
      
      if (this.allNodesSpecified) {
        return;
      }
      this.inAuditMode = true;
      // Kick off all searches
      
      let nodes = this.needingAudit.map(this.$store.getters["table_of_contents/getNode"]);
      slowSearches(nodes);
      let target = this.needingAudit[0];
      this.auditStep(target);
    },
    auditStep: function(id) {
      // reveal the ID
      this.$store
        .dispatch("table_of_contents/revealNode", {
          casebook: this.casebook,
          id
        })
        .then(() => {
          // Zoom to it
          const node = this.$store.getters["table_of_contents/getNode"](id);
          if (!node) return;
          const url_parts = node.url.split("/");
          const hash = url_parts[url_parts.length - 2];
          let elem = document.getElementById(hash);
          let y = elem.getBoundingClientRect().top + window.pageYOffset - 60;
          window.scrollTo({ top: y, behavior: "smooth" });
          //elem.scrollIntoView({block: "start", inline: "nearest", behavior: 'smooth'});
          // Augment the node with the audit-portal
          this.$store.dispatch("table_of_contents/setAudit", { id });
        });
    },
  },
  watch: {
    allSearchResults: function(newVal) {
      const self = this;
      newVal.forEach(({ url, id, results }) => {
        function handleSubmitResponse(id) {
          return (response) => {
            self.$store.dispatch("table_of_contents/clearAudit", { id });
            self.$store.dispatch("table_of_contents/fetch", {
              casebook: self.casebook,
              subsection: self.section
            });
          };
        }
        if (results && results !== "pending" && results.length === 1) {
          const data = { from: "Temp", to: "Case", cap_id: results[0].id };
          if (!_.has(self.autoAudited, id)) {
            self.autoAudited[id] = true;
            Axios.patch(url, data).then(
              handleSubmitResponse(id),
              console.error
            );
          }
        }
      });
    },
    currentAuditId: function(newVal) {
        if (newVal === "None") {
            this.inAuditMode = false;
        }
        if (this.inAuditMode) {
        this.auditStep(this.currentAuditId);
      }
    }
  },
  computed: {
    inAuditMode: { 
      get: function() {
        return this.$store.getters['globals/inAuditMode']();
      },
      set: function(val) {
        this.$store.commit('globals/setAuditMode', val);
      }
    },
    currentAuditId: function() {
      return this.needingAudit.length > 0 ? this.needingAudit[0] : "None";
    },
    casebook: function() {
      return this.$store.getters["globals/casebook"]();
    },
    needingAudit: function() {
      return this.$store.getters["table_of_contents/auditTargets"](
        this.casebook
      );
    },
    allSearchResults: function() {
      let allNodes = [];
      this.needingAudit.forEach(id => {
        const node = this.$store.getters["table_of_contents/getNode"](id);
        if (node && node.resource_type === 'Temp') {
          const query = pp.extractCaseSearch(node.title);
          allNodes.push({url: node.url, id:node.id, results: this.$store.getters["case_search/getSearch"]({ query })});
        }
      });
      return allNodes;
    },
    allNodesSpecified: function() {
      return this.needingAudit.length === 0;
    }
  }
};
</script>

<style lang="scss">
button.action.audit-casebook {
  background-image: url('~static/images/ui/casebook/audit-casebook.svg');
}
</style>
