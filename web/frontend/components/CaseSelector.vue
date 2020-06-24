<template>
  <div id="case-selector">
    <div v-if="done">
      <div class="done-message">  
        All cases specified, saving your changes
      </div>
      <loading-spinner></loading-spinner>
    </div>
    <div class="add-resource-body" v-else>
      <span>
        Select a case for
        <strong>{{this.currentTitle}}</strong> 
      </span>
      <span class="case-progress">{{identifiedCases}}/{{totalCases}}</span>
      <case-results 
        :queryObj="caseQueryObj"
        @choose="selectCase"
        />
      <case-searcher
        :search-on-top="false"
        :can-cancel="true"
        v-model="caseQueryObj"
        @choose="selectCase"
       />
      <input
        style="margin-top:-4px;"
        class="search-button"
        type="submit"
        value="Skip"
        v-on:click.stop.prevent="selectTextBlock"
      />
    </div>
  </div>
</template>

<script>
import _ from "lodash";
import LoadingSpinner from "./LoadingSpinner";
import CaseSearcher from "./CaseSearcher";
import CaseResults from "./CaseResults";

import { createNamespacedHelpers } from "vuex";
const { mapActions } = createNamespacedHelpers("case_search");

export default {
  components: { 
    LoadingSpinner,
    CaseSearcher,
    CaseResults
   },
  props: ["value"],
  data: () => ({ caseQueryObj: {query:""}, caseIndex: 0, done: false}),
  computed: {
    lastChoice: function() {
      return this.caseIndex === this.value.length - 1;
    },
    currentCase: function() {
      return this.value[this.caseIndex][0].case_query;
    },
    currentTitle: function() {
      return this.value[this.caseIndex][0].title;
    },
    identifiedCases:function() {
      return this.caseIndex+1;  
    },
    totalCases: function() {
      return this.value.length;
    }
  },
  mounted: function() {
    this.caseQueryObj = {query: this.currentCase};
  },
  methods: {
    ...mapActions(["fetch"]),
    displayModal: function displayModal() {
      this.showModal = true;
    },
    properType: function properType() {
      return this.sectionType[0].toUpperCase() + this.sectionType.substr(1);
    },
    setTab: function setTab(newTab) {
      const self = this;
      let tries = 0;
      function tryFocus() {
        if (self.$refs.case_search) {
          self.$refs.case_search.focus();
        } else {
          tries += 1;
          if (tries < 10) self.$nextTick(tryFocus);
        }
      }
      this.currentTab = newTab;
      tryFocus();
    },
    selectTextBlock: function() {
      this.selectCase({id:"TextBlock"});
    },
    selectCase: function(c) {
      this.value[this.caseIndex][1] = c.id;
      this.caseIndex += 1;
      if (this.caseIndex === this.value.length) {
        this.done = true;
        this.caseIndex -=1;
        this.$emit('done', this.value);
      }
      this.caseQueryObj = {query: this.currentCase};
      this.fetch(this.caseQueryObj);
      this.$emit("input", this.value);
    }
  }
};
</script>

<style lang="scss">
@use "sass:color";
@import "variables";
label.textarea {
  width: 100%;
}
.search-tabs {
  display: flex;
  flex-direction: row;
  a.search-tab {
    color: black;
  }
}
span.case-progress {
    float: right;
}
form.case-search div {
    margin: 8px 0px;
    margin-left: 8px;
}


.search-alert {
  display: flex;
  flex-direction: row;
  .spinner-message {
    flex-direction: column;
    align-content: center;
    justify-content: center;
    display: flex;
    margin-right: 14px;
    margin-left: 12px;
  }
}
.done-message {
    float: left;
    margin-top: 10px;
}
</style>
