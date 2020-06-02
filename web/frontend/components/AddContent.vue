<template>
  <div id="section-cloner">
    <button
      class="action one-line add-resource"
      v-on:click.stop.prevent="displayModal()"
    >Add Resource</button>
    <Modal v-if="showModal" @close="showModal = false" :initial-focus="() => $refs.case_search">
      <template slot="title">Add Resource</template>
      <template slot="body">
        <div class="search-tabs">
          <a
            v-bind:class="{ active: caseTab, 'search-tab': true }"
            v-on:click.stop.prevent="setTab('case')"
          >Find Case</a>
          <a
            v-bind:class="{ active: textTab, 'search-tab': true }"
            v-on:click.stop.prevent="setTab('text')"
          >Create Text</a>
          <a
            v-bind:class="{ active: linkTab, 'search-tab': true }"
            v-on:click.stop.prevent="setTab('link')"
          >Add Link</a>
        </div>
        <div class="add-resource-body" v-if="caseTab">
          <form class="case-search">
            <input
              id="case_search"
              ref="case_search"
              class="form-control"
              name="q"
              type="text"
              placeholder="Search for a case to import"
              v-model="caseQuery"
              v-focus
            />
            <input
              class="search-button"
              type="submit"
              value="Search"
              v-on:click.stop.prevent="runCaseSearch()"
            />
          </form>
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
            <div class="search-results-entry" v-else v-for="c in caseResults" :key="c.id">
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
                <div class="date-column"><a v-on:click.stop.prevent="selectCase(c)" class="wrapper">{{c.decision_date}}</a></div>
              <div class="preview-column">
                <a :href="c.url" target="_blank" rel="noopener noreferrer">CAP</a>
              </div>
            </div>
          </div>
        </div>
        <div class="add-resource-body" v-else-if="textTab">
          <form ref="textForm" class="new-text" v-on:submit.stop.prevent="submitTextForm()">
            <div v-bind:class="{'form-group': true, 'has-error': errors.name}">
              <label class="title">
                Text title
                <input
                  class="form-control"
                  name="name"
                  type="text"
                  v-model="textTitle"
                  v-focus
                />
                <span class="help-block" v-if="errors.name">
                  <strong>{{errors.name[0].message}}</strong>
                </span>
              </label>
            </div>
            <div v-bind:class="{'form-group': true, 'has-error': errors.content}">
              <label class="textarea">
                Text body
                <editor
                  ref="text-body"
                  name="content"
                  :init="tinyMCEInitConfig"
                  v-model="textContent"
                ></editor>
                <span class="help-block has-error" v-if="errors.content">
                  <strong>{{errors.content[0].message}}</strong>
                </span>
              </label>
            </div>
            <input class="save-button" type="submit" value="Save text" />
          </form>
        </div>
        <div class="add-resource-body" v-else>
          <h3>Enter the URL of any asset to link from the web.</h3>
          <h4>Some examples: YouTube videos, PDFs, JPG, PNG, or GIF images</h4>
          <form ref="linkForm" class="new-link" v-on:submit.stop.prevent="submitLinkForm()">
            <div v-bind:class="{'form-group': true, 'has-error': errors.url}">
              <input
                class="form-control"
                name="url"
                type="text"
                placeholder="Enter a URL to add it to your casebook"
                v-model="linkTarget"
                v-focus
              />
              <span class="help-block has-error" v-if="errors.url">
                <strong>{{errors.url[0].message}}</strong>
              </span>
            </div>
            <input class="search-button" type="submit" value="Add linked resource" />
          </form>
        </div>
      </template>
    </Modal>
  </div>
</template>

<script>
import Modal from "./Modal";
import LoadingSpinner from "./LoadingSpinner";
import Editor from "@tinymce/tinymce-vue";
import Axios from "../config/axios";
import _ from "lodash";
import { createNamespacedHelpers } from "vuex";
const { mapActions } = createNamespacedHelpers("case_search");

export default {
  components: {
    Modal,
    LoadingSpinner,
    editor: Editor
  },
  props: ["casebook", "section"],
  data: () => ({
    showModal: false,
    currentTab: "case",
    caseQuery: "",
    tinyMCEInitConfig: {
      plugins: "lists paste",
      skin_url: "/static/tinymce_skin",
      menubar: false,
      branding: false,
      toolbar: "undo redo | numlist indent outdent | paste",
      valid_elements: "div,ol,li,span",
      paste_enable_default_filters: false
    },
    textTitle: "",
    textContent: "",
    linkTarget: "",
    errors: {}
  }),
  computed: {
    caseTab: function() {
      return this.currentTab === "case";
    },
    textTab: function() {
      return this.currentTab === "text";
    },
    linkTab: function() {
      return this.currentTab === "link";
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
          citations.filter(x => (x.type = "official")).map(x => x.cite)
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
      return "pending" === this.$store.getters["case_search/getSearch"](this.caseQuery);
    },
    emptyResults: function() {
      return this.caseResults && this.caseResults.length == 0;
    }
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
      function tryFocus() {
        if (self.$refs.case_search) {
          self.$refs.case_search.focus();
        } else {
          this.$nextTick(tryFocus)
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
    submitCaseForm: function submitCaseForm() {},
    submitTextForm: function submitTextForm() {
      let formData = new FormData(this.$refs.textForm);
      formData.append("section", this.section);
      formData.set("content", this.textContent);
      const url = `/casebooks/${this.casebook}/new/text`;
      Axios.post(url, formData).then(
        this.handleSubmitResponse,
        this.handleSubmitErrors
      );
    },
    submitLinkForm: function submitLinkForm() {
      let formData = new FormData(this.$refs.linkForm);
      formData.append("section", this.section);
      const url = `/casebooks/${this.casebook}/new/link`;
      Axios.post(url, formData).then(
        this.handleSubmitResponse,
        this.handleSubmitErrors
      );
    },
    selectCase: function(c) {
      const CAPAPI_LOADER_URL = "/cases/from_capapi";
      let formData = new FormData();
      formData.append("parent", this.section);
      const url = `/casebooks/${this.casebook}/new/case`;
      const handler = this.handleSubmitResponse;
      Axios.post(CAPAPI_LOADER_URL, { id: c.id }).then(resp => {
        formData.append("resource_id", resp.data.id);
        Axios.post(url, formData).then(handler, this.handleSubmitErrors);
      });
    },
    handleSubmitResponse: function handleSubmitResponse(response) {
      let location = response.request.responseURL;
      window.location.href = location;
      this.errors = {};
    },
    handleSubmitErrors: function handleSubmitErrors(error) {
      if (error.response.data) {
        this.errors = error.response.data;
      }
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
a.search-tab {
  color: black;
}

.search-results {
  overflow-y: unset;
  overflow-x: unset;
  display:table;
  width: 100%;
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
      display:table-cell;
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
</style>
