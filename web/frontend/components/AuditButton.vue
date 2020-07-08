<template>
  <div id="audit-flow">
    <publish-button v-if="allNodesSpecified"></publish-button>
    <button class="action audit-casebook" v-on:click="startAudit()" v-else>Finalize entries</button>
  </div>
</template>

<script>
import _ from "lodash";
import pp from "../libs/text_outline_parser";
import PublishButton from "./PublishButton";

export default {
  components: {
    PublishButton
  },
  data: () => ({ inAuditMode: false }),
  methods: {
    startAudit: function() {
      if (this.allNodesSpecified) {
        return;
      }
      this.inAuditMode = true;
      // Kick off all searches
      this.needingAudit.forEach(id => {
        let node = this.$store.getters["table_of_contents/getRawNode"](
          this.casebook,
          id
        );
        if (node && _.has(node, "title")) {
          let query = pp.extractCaseSearch(node.title);
          this.$store.dispatch("case_search/fetch", { query });
        }
      });
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
          const node = this.$store.getters["table_of_contents/getRawNode"](
            this.casebook,
            id
          );
          const url_parts = node.url.split("/");
          const hash = url_parts[url_parts.length - 2];
          let elem = document.getElementById(hash);
          let y = elem.getBoundingClientRect().top + window.pageYOffset - 60;
          window.scrollTo({ top: y, behavior: "smooth" });
          //elem.scrollIntoView({block: "start", inline: "nearest", behavior: 'smooth'});
          // Augment the node with the audit-portal
          this.$store.dispatch("table_of_contents/setAudit", { id });
        });
    }
  },
  watch: {
    currentAuditId: function(newVal) {
      if (this.inAuditMode) {
        this.auditStep(this.currentAuditId);
      }
    }
  },
  computed: {
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
    allNodesSpecified: function() {
      return this.needingAudit.length === 0;
    }
  }
};
</script>

<style lang="scss">
button.action.audit-casebook {
  background-image: url(/static/dist/img/audit-casebook.f96e34fb.svg);
}
</style>
