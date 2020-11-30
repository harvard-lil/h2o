<template>
<div class="search-results">
  <div v-for="source in searchResults" :key="source.id">
    <div>
      {{source.name}}: <i class="source-description">{{source.short_description}}</i>
      <input type="checkbox" :checked="source.enabled" @change="internalToggleSource(source.id)"/>
    </div>
    <div v-if="source.enabled">
      <div class="search-alert" v-if="source.pendingCaseFetch">
        <div class="spinner-message">
          <div>Searching</div>
        </div>
        <loading-spinner></loading-spinner>
      </div>
      <div class="search-results-wrapper" v-else-if="source.emptyResults">
        <div class="search-alert">
          <span>No cases found matching your search</span>
        </div>
      </div>
      <div class="search-results-wrapper" v-else>
        <div class="search-results-entry" v-for="c in source.results" :key="c.id">
          <div class="name-column">
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
          <div class="preview-column">
            <a :href="c.url" target="_blank" rel="noopener noreferrer">{{ source.name }}</a>
          </div>
        </div>
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
      const tempResults = this.getSearch()(this.delayedObj);
      if (!tempResults || !this.sources) return [];
      let augmentedResults = this.sources.map(x => {
        const results = tempResults[x.sourceIndex];
        return {
          ...x,
          pendingCaseFetch: results && !_.isArray(results) && results === 'pending',
          emptyResults: results && _.isArray(results) && results.length === 0,
          disabled: results && !_.isArray(results) && results === 'disabled',
          timeout: results && !_.isArray(results) && results === 'timeout',
          results: results
        }
      });
      augmentedResults.sort((a,b) => a.disabled < b.disabled)
      return augmentedResults;
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
      console.log(source_id);
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
