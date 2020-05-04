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
      <div class="search-results" id="case-search-results">
        <div class="search-alert" v-if="pendingCaseFetch">
          <div class="spinner-message">
            <div>Searching</div>
          </div>
          <loading-spinner></loading-spinner>
        </div>
        <div class="search-alert" v-else-if="emptyResults">
          <span>No cases found matching your search</span>
        </div>
        <div class="search-results-wrapper" v-else>
          <div class="search-results-entry" v-for="c in caseResults" :key="c.id">
            <div class="name-column">
              <a v-on:click.stop.prevent="selectCase(c)" class="wrapper">
                <span :title="c.fullName">{{c.shortName}}</span>
              </a>
            </div>
            <div class="cite-column">
              <a v-on:click.stop.prevent="selectCase(c)" class="wrapper">
                <span :title="c.allCitations">{{c.citations}}</span>
              </a>
            </div>
            <div class="date-column">
              <a v-on:click.stop.prevent="selectCase(c)" class="wrapper">{{c.decision_date}}</a>
            </div>
            <div class="preview-column">
              <a :href="c.url" target="_blank" rel="noopener noreferrer">CAP</a>
            </div>
          </div>
        </div>

        <form class="case-search">
          <div> If you don't see your case above:</div>
          <label>
            Search by another name or citation
            <input
              id="case_search"
              ref="case_search"
              class="form-control"
              name="q"
              type="text"
              placeholder="Search for a case to import"
              v-model="caseQuery"
            />
          </label>
          <input
            style="margin-top:-4px;"
            class="search-button"
            type="submit"
            value="Search"
            v-on:click.stop.prevent="runCaseSearch"
          />
          <div class="or-clause"><span>Or</span></div>
          <input
            style="margin-top:-4px;"
            class="search-button"
            type="submit"
            value="Enter this case manually"
            v-on:click.stop.prevent="selectTextBlock"
          />
        </form>
      </div>
    </div>
  </div>
</template>

<script>
import Vue from "vue";
import LoadingSpinner from "./LoadingSpinner";
import _ from "lodash";
import { createNamespacedHelpers } from "vuex";
const { mapActions } = createNamespacedHelpers("case_search");

export default {
  components: { LoadingSpinner },
  props: ["value"],
  data: () => ({ caseQuery: "", caseIndex: 0, done: false}),
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
      let results = this.$store.getters["case_search/getSearch"](
        this.caseQuery
      );
      return (
        results &&
        _.isArray(results) &&
        results.map(c => ({
          shortName: truncatedCaseName(c),
          fullName: c.name,
          citations: preferedCitations(this.caseQuery, c),
          allCitations: c.citations
            ? c.citations.map(x => x.name).join(", ")
            : "",
          url: c.frontend_url,
          id: c.id,
          decision_date: c.decision_date
        }))
      );
    },
    pendingCaseFetch: function() {
      return (
        "pending" ===
        this.$store.getters["case_search/getSearch"](this.caseQuery)
      );
    },
    emptyResults: function() {
      return this.caseResults && this.caseResults.length == 0;
    }
  },
  mounted: function() {
    this.caseQuery = this.currentCase;
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
    runCaseSearch: function runCaseSearch() {
      if (this.caseQuery !== "") {
        this.fetch({ query: this.caseQuery });
      }
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
      Vue.set(this, "caseQuery", this.currentCase);
      this.runCaseSearch();
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
      &.name-column {
      }
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
