<template>
<div class="search-results">
  <div class="search-alert" v-if="searchResults.allPending">
    <div class="spinner-message">
      <div>Searching</div>
    </div>
    <loading-spinner></loading-spinner>
  </div>
  <div class="search-results-wrapper" v-else-if="searchResults.emptyResults">
    <div class="search-alert">
      <span>No legal documents found matching your search</span>
    </div>
  </div>
  <div class="search-results-wrapper" v-else-if="searchResults.unRun">
  <!-- can we add search as we type here?  -->
    <div class="search-alert">
      <!-- change message: type in ~ to search for law sections or caselaws to add to your book. Then press search to see results.  -->
      <span>Click Search to run your search</span>
    </div>
  </div>
  <div class="search-results-wrapper" v-else>
    <div class="search-results-entry" v-for="c in searchResults.results" :key="c.id">
      <div class="name-column">
        <!-- add headers for all these columns -->
         <!-- clarification on how to add cases to your book. double click? click the link?  -->
         <!-- add feedback to user when case has been added succesfully to your book -->
        <a v-on:click.stop.prevent="emitChoice(c)" class="wrapper">
          <span :title="c.fullName">{{c.shortName}}</span>
        </a>
      </div>
      <div class="cite-column">
        <a v-on:click.stop.prevent="emitChoice(c)" class="wrapper">
          <span :title="c.fullCitations">{{c.shortCitations}}</span>
        </a>
      </div>
      <div class="date-column">
        <a v-on:click.stop.prevent="emitChoice(c)" class="wrapper">{{c.effectiveDate}}</a>
      </div>
      <!--link to open book in ~ add title to table columns -->
      <div class="preview-column">
        <a :href="c.url" target="_blank" rel="noopener noreferrer">{{ c.sourceName }}</a>
      </div>
    </div>
  </div>
</div>
</template>

<script>
import _ from "lodash";
import LoadingSpinner from "./LoadingSpinner";
import { createNamespacedHelpers } from "vuex";
const { mapActions, mapGetters } = createNamespacedHelpers("case_search");

export default {
  components: {
    LoadingSpinner
  },
  data: () => ({delayedObj: {}}),
  props: ["queryObj"],
  watch: {
    queryObj: _.debounce(function(newVal){
      this.delayedObj = newVal;
    },1000)
  },
  computed: {
    sources: function() {
      return this.getSources();
    },
    searchResults: function() {
      return this.getSearch()(this.delayedObj);
    }
  },
  methods: {
    ...mapGetters(['getSearch', 'getSources']),
    ...mapActions(["toggleSource"]),    
    emitChoice: function(c) {
      this.$emit("choose", c);
    },
    internalToggleSource: function(source_id) {
      this.toggleSource({source_id, queryObj: this.delayedObj});
    }
  },
  mounted: function() {
    this.delayedObj = this.queryObj;
  }
};
</script>

<style lang="scss" scoped>
@use "sass:color";
@import "variables";
.search-results {
    max-height: 20rem;
    overflow-y: scroll;
}
.source-description {
    padding-left: 0.5rem;
    padding-right: 1rem;
}
.search-results-wrapper {
  overflow-y: unset;
  overflow-x: unset;
  display: table;
  width: 100%;
  border-top: 2px solid black;
  border-bottom: 2px solid black;
  margin: 8px 0;
  padding: 2px 0;
  .search-results-entry {
    display: table-row;
    div {
      padding: 0.4rem 0.2rem;
      &.cite-column {
        min-width: 9rem;
      }
      &.date-column {
        min-width: 9rem;
      }
      &.preview-column {
        width: 6rem;
      }
      display: table-cell;
    }

    &:hover {
      background-color: color.adjust($light-blue, $alpha: -0.75);
      cursor: pointer;
    }
    a[target="_blank"]:after {
      content: url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAQElEQVR42qXKwQkAIAxDUUdxtO6/RBQkQZvSi8I/pL4BoGw/XPkh4XigPmsUgh0626AjRsgxHTkUThsG2T/sIlzdTsp52kSS1wAAAABJRU5ErkJggg==);
      margin: 0 3px 0 5px;
      color: black;
    }
  }
}

</style>
