<template>
  <div class="search-results" id="case-search-results">
    <div class="search-alert" v-if="pendingCaseFetch">
      <div class="spinner-message">
        <div>Searching</div>
      </div>
      <loading-spinner></loading-spinner>
    </div>
    <div class="search-results-wrapper" v-else-if="emptyResults">
    <div class="search-alert">
      <span>No cases found matching your search</span>
    </div>
    </div>
    <div class="search-results-wrapper" v-else>
      <div class="search-results-entry" v-for="c in caseResults" :key="c.id">
        <div class="name-column">
          <a v-on:click.stop.prevent="emitChoice(c)" class="wrapper">
            <span :title="c.fullName">{{c.shortName}}</span>
          </a>
        </div>
        <div class="cite-column">
          <a v-on:click.stop.prevent="emitChoice(c)" class="wrapper">
            <span :title="c.allCitations">{{c.citations}}</span>
          </a>
        </div>
        <div class="date-column">
          <a v-on:click.stop.prevent="emitChoice(c)" class="wrapper">{{c.decision_date}}</a>
        </div>
        <div class="preview-column">
          <a :href="c.url" target="_blank" rel="noopener noreferrer">CAP</a>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import _ from "lodash";
import LoadingSpinner from "./LoadingSpinner";

export default {
  components: {
    LoadingSpinner
  },
  props: ["queryObj"],
  computed: {
    pendingCaseFetch: function() {
      return (
        "pending" === this.$store.getters["case_search/getSearch"](this.queryObj)
      );
    },
    emptyResults: function() {
      return this.caseResults && this.caseResults.length == 0;
    },
    caseResults: function() {
      function truncatedCaseName({ name }) {
        const maxPartLength = 40;
        const vsChecker = / [vV][sS]?[.]? /;
        let splits = name.split(vsChecker);
        if (splits.length !== 2) {
          let ret = name.substr(0, maxPartLength * 2 + 4);
          return ret + (name.length > ret.length ? "..." : "");
        }
        let partA = splits[0].substr(0, maxPartLength);
        partA += splits[0].length > partA.length ? "..." : "";
        let partB = splits[1].substr(0, maxPartLength);
        partB += splits[0].length > partA.length ? "..." : "";
        return `${partA} v. ${partB}`;
      }
      function preferedCitations(query, { citations }) {
        if (!citations) {
          return "";
        }
        let cites = citations
          .filter(x => x.cite == query.trim())
          .map(x => x.cite);
        cites = cites.concat(
          citations.filter(x => x.type === "official").map(x => x.cite)
        );
        cites = cites.concat(
          citations.map(x => x.cite).filter(x => cites.indexOf(x) == -1)
        );
        const ret = cites.slice(0, 2).join(", ");
        return ret;
      }
      let results = this.$store.getters["case_search/getSearch"](this.queryObj);
      return (
        results &&
        _.isArray(results) &&
        results.map(c => ({
          shortName: truncatedCaseName(c),
          fullName: c.name,
          citations: preferedCitations(this.queryObj.query, c),
          allCitations: c.citations
            ? c.citations.map(x => x.name).join(", ")
            : "",
          url: c.frontend_url,
          id: c.id,
          decision_date: c.decision_date
        }))
      );
    }
  },
  methods: {
    emitChoice: function(c) {
      this.$emit("choose", c);
    }
  }
};
</script>

<style lang="scss" scoped>
@use "sass:color";
@import "variables";
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
