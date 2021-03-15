<template>
  <div id="audit-flow">
    <button class="action one-line save" v-if="dirtyForm" v-on:click.stop.prevent="save">Save</button>
    <publish-button v-else-if="allNodesSpecified"></publish-button>
    <button class="action audit-casebook" v-on:click.stop.prevent="startAudit()" v-else>Finalize entries</button>
  </div>
</template>

<script>
import _ from "lodash";
import _tinymce from 'tinymce/tinymce';
import PublishButton from "./PublishButton";
import Axios from "../config/axios";
import urls from "../libs/urls";
import Vue from "vue";
import { createNamespacedHelpers } from "vuex";
import pp from "../libs/text_outline_parser";

const { mapGetters } = createNamespacedHelpers("case_search");


const bus = new Vue();

Vue.component('DirtyForm',{
  data: () => ({fired: false}),
  props: ['cssClass', 'formMethod'],
  mounted: function() {
    for(let k of this.$refs.form.elements) {
      if (k.id) {
        k.addEventListener('input', this.emitDirty);
      }
    }
    const self = this;
    setTimeout(() => {
      window.tinyMCE.editors.forEach(editor => {
        editor.on('input', self.emitDirty);
      }, 100)
    })
  },
  methods: {
    emitDirty: function() {
      if (this.fired) return;
      bus.$emit('dirtiedForm', {})
      this.fired = true;
    }
  },
  //template: '<div ref="parent"><slot></slot></div>'
  template: '<form ref="form" :class="cssClass" :method="formMethod"><slot></slot></form>'
})

export default {
  components: {
    PublishButton
  },
  data: () => ({autoAudited: {},
                dirtyForm: false}),
  methods: {
    save: function() {
      let form = document.querySelector('form.edit_content_resource') || document.querySelector('form.edit_content_section') || document.querySelector('form.edit_content_casebook');
      form.submit()
    },
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
            let lineGuess = pp.guessLineType(node.title);
            if (lineGuess.resource_type === 'Temp') {
              lineGuess.guesses.forEach(({query, source}) => {
                self.$store.dispatch("case_search/fetchForSource", {queryObj:{ query } ,source});
              })
            } else {
              let queryObj = {query: node.title};
              self.$store.dispatch("case_search/fetchForAllSources", { queryObj });
            }
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
    handleSubmitResponse: function handleSubmitResponse(id) {
      this.$store.dispatch("table_of_contents/clearAudit", {id});
      this.$store.dispatch("table_of_contents/fetch", {
        casebook: this.casebook,
        subsection: this.section
      });
    },
    handleSubmitErrors: function handleSubmitErrors(error) {
      console.error(error);
    }    
  },
  watch: {
    allSearchResults: function(newVal) {
      console.log("Recalculating allSearchResults");
      const self = this;
      newVal.forEach(({ url, id, queryObj, searchResults }) => {
        if (searchResults &&
            _.has(searchResults, 'results') &&
            _.isArray(searchResults.results) &&
            searchResults.results.length === 1) {
          let foundDoc = searchResults.results[0];
          const data = { from: "Temp", to: "LegalDocument", id: foundDoc.id, source_id: foundDoc.source_id, title: foundDoc.shortName};
          if (!_.has(this.autoAudited, id)) {
            this.autoAudited[id] = true;
            Axios.patch(url, data).then(
              () => self.handleSubmitResponse(id),
              this.handleSubmitError
            );
          }
        }
      });
    },
    "$store.state.case_search.searches": function(newVal) {
      console.log("New Search Results");
      console.log(newVal);
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
    ...mapGetters(['getSources', 'getSearch']),
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
    allNodesNeedingSearch: function() {
      let allNodes = [];
      let self = this;
      this.needingAudit.forEach(id => {
        const node = this.$store.getters["table_of_contents/getNode"](id);
        if (node && node.resource_type === 'Temp') {
          if (_.has(node, "title")) {
            let lineGuess = pp.guessLineType(node.title, this.getSources);
            if (lineGuess.resource_type === 'Temp') {
              lineGuess.guesses.forEach(guess => {
                let query = guess.query;
                let source = guess.source;
                self.$store.dispatch("case_search/fetchForSource", {queryObj:{ query } ,source });
              })
              let queryObj = {query: lineGuess.guesses[0].query};
              allNodes.push({url: node.url, id:node.id, queryObj});
            } else {
              let queryObj = {query: node.title};
              self.$store.dispatch("case_search/fetchForAllSources", { queryObj });
              allNodes.push({url: node.url, id:node.id, queryObj});
            }
          }

        }
      });
      return allNodes;
    },
    allSearchResults: function() {
      return this.allNodesNeedingSearch.map(node => ({...node,
                                                      searchResults: this.getSearch(node.queryObj)}));
    },
    allNodesSpecified: function() {
      return this.needingAudit.length === 0;
    }
  },
  created: function() {
    const self = this;
    bus.$on('dirtiedForm', () => {
      self.dirtyForm = true;
    })
  }
};
</script>

<style lang="scss">
button.action.audit-casebook {
  background-image: url('~static/images/ui/casebook/audit-casebook.svg');
}
</style>
