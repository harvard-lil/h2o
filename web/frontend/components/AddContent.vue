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
          <div class="results-list" id="case-search-results">
            <div v-if="pendingCaseFetch">
              <div class="spinner"></div>
            </div>
            <div v-else>
              <a v-on:click.stop.prevent="selectCase(c)" class="wrapper" v-for="c in caseResults" :key="c.id">
                <div class="results-entry">
                  <div class="title">{{c.name}}</div>
                  <div class="citation">{{c.citations.map(x => x.cite).join(", ")}}</div>
                  <div class="date">{{c.decision_date}}</div>
                </div>
              </a>
            </div>
          </div>
        </div>
        <div class="add-resource-body" v-else-if="textTab">
          <form class="new-text" v-on:submit.stop.prevent="submitTextForm()">
            <div class="form-group">
              <label class="title">
                Text title
                <input class="form-control" name="title" type="text" v-model="textTitle" v-focus/>
              </label>
            </div>
            <div class="form-group">
              <label class="textarea">
                Text body
                <editor ref="text-body" :init="tinyMCEInitConfig" v-model="textContent"></editor>
              </label>
            </div>
            <input class="save-button" type="submit" value="Save text" />
          </form>
        </div>
        <div class="add-resource-body" v-else>
          <h3>Enter the URL of any asset to link from the web.</h3>
          <h4>Some examples: YouTube videos, PDFs, JPG, PNG, or GIF images</h4>
          <form class="new-link" v-on:submit.stop.prevent="submitLinkForm()">
            <input
              class="form-control"
              name="url"
              type="text"
              placeholder="Enter a URL to add it to your casebook"
              v-model="linkTarget"
              v-focus
            />
            <input class="search-button" type="submit" value="Add linked resource" />
          </form>
        </div>
      </template>
    </Modal>
  </div>
</template>

<script>
import Modal from "./Modal";
import Editor from "@tinymce/tinymce-vue";
import Axios from "../config/axios";
import { createNamespacedHelpers } from "vuex";
const { mapActions } = createNamespacedHelpers("case_search");

export default {
  components: {
    Modal,
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
    linkTarget: ""
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
      return this.$store.getters["case_search/getSearch"](this.caseQuery);
    },
    pendingCaseFetch: function() {
      return this.caseResults === 'pending';
    }
  },
  methods: {
    ...mapActions(["fetch"]),
    blurCaseSearch: function(e) {
      console.log(e);
    },
    displayModal: function displayModal() {
      this.showModal = true;
    },
    properType: function properType() {
      return this.sectionType[0].toUpperCase() + this.sectionType.substr(1);
    },
    setTab: function setTab(newTab) {
      this.currentTab = newTab;
      if (this.caseTab) {
        this.$nextTick(() => {
          console.log(this.$refs)
          this.$refs.case_search.focus();
        })
      }
    },
    runCaseSearch: function runCaseSearch() {
      if (this.caseQuery !== "") {
        this.fetch({ query: this.caseQuery });
      }
    },
    submitCaseForm: function submitCaseForm() {},
    submitTextForm: function submitTextForm() {
      const data = {
        parent: this.section,
        resource_id: null,
        text: { title: this.textTitle, content: this.textContent }
      };
      const url = FRONTEND_URLS.new_section_or_resource.replace(
        "$CASEBOOK_ID",
        this.casebook
      );
      Axios.post(url, data).then(this.handleSubmitResponse, console.error);
    },
    submitLinkForm: function submitLinkForm() {
      const data = {
        parent: this.section,
        resource_id: null,
        link: { url: this.linkTarget }
      };
      const url = FRONTEND_URLS.new_section_or_resource.replace(
        "$CASEBOOK_ID",
        this.casebook
      );
      Axios.post(url, data).then(this.handleSubmitResponse, console.error);
    },
    selectCase: function(c) {
      const CAPAPI_LOADER_URL = '/cases/from_capapi';
      let data = {
        parent: this.section,
        resource_id: c.id
      };
      const url = FRONTEND_URLS.new_section_or_resource.replace(
        "$CASEBOOK_ID",
        this.casebook
      );
      const handler = this.handleSubmitResponse;
      Axios.post(CAPAPI_LOADER_URL, {id: c.id}).then((resp) => {
        data.resource_id = resp.data.id;
        Axios.post(url, data).then(handler, console.error);
      })
    },
    handleSubmitResponse: function handleSubmitResponse(response) {
      let location = response.request.responseURL;
      window.location.href = location;
    }
  },
};
</script>

<style lang="scss">
@use "sass:color";
@import 'variables';
label.textarea {
  width: 100%;
}
a.search-tab {
  color: black;
}

#case-search-results {
  overflow-y: unset;
  overflow-x: unset;

  .results-entry {
    &:hover{
      background-color: color.adjust($light-blue, $alpha: -0.75);
      cursor: pointer;
    }
  }
}
</style>
