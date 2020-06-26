<template>
  <div class="type-picker">
    <h4>This is a temporary entry in your casebook. Finish it below.</h4>
    <div>
      <div class="type-tabs">
        <a
          v-bind:class="{ active: caseTab, 'tab': true }"
          v-on:click.stop.prevent="setTab('case')"
        >Case</a>
        <a
          v-bind:class="{ active: textTab, 'tab': true }"
          v-on:click.stop.prevent="setTab('text')"
        >Text</a>
        <a
          v-bind:class="{ active: linkTab, 'tab': true }"
          v-on:click.stop.prevent="setTab('link')"
        >Link</a>
      </div>
      <div class="modal-body">
        <div class="add-resource-body" v-if="caseTab">
          <case-searcher
            :search-on-top="false"
            :can-cancel="true"
            v-model="caseQueryObj"
            @choose="selectCase"
          />
          <case-results :queryObj="caseQueryObj" @choose="selectCase" />
        </div>
        <div class="add-resource-body" v-else-if="textTab">
          <form ref="textForm" class="new-text" v-on:submit.stop.prevent="submitTextForm()">
            <div v-bind:class="{'form-group': true, 'has-error': errors.content}">
              <label class="textarea">
                Text body
                <editor
                  ref="text_body"
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
        <div class="add-resource-body" v-else-if="linkTab">
          <h3>Enter the URL of any asset to link from the web.</h3>
          <h4>Some examples: YouTube videos, PDFs, JPG, PNG, or GIF images</h4>
          <form ref="linkForm" class="new-link" v-on:submit.stop.prevent="submitLinkForm()">
            <div v-bind:class="{'form-group': true, 'has-error': errors.url}">
              <input
                class="form-control"
                ref="link_body"
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
      </div>
    </div>
  </div>
</template>

<script>
import CaseSearcher from "./CaseSearcher";
import CaseResults from "./CaseResults";
import Editor from "@tinymce/tinymce-vue";
import Axios from "../config/axios";
import _ from "lodash";
import { createNamespacedHelpers } from "vuex";
const { mapActions } = createNamespacedHelpers("case_search");

export default {
  components: {
    CaseSearcher,
    CaseResults,
    editor: Editor
  },
  props: ["casebook", "section"],
  data: () => ({
    showModal: false,
    currentTab: "case",
    caseQueryObj: { query: "" },
    tinyMCEInitConfig: {
      plugins: ["link", "lists", "image", "table"],
      skin_url: "/static/tinymce_skin",
      menubar: false,
      branding: false,
      toolbar:
        "undo redo removeformat | styleselect | bold italic underline | numlist bullist indent outdent | table blockquote link image"
    },
    textTitle: "",
    textContent: "",
    linkTarget: "",
    errors: {}
  }),
  computed: {
    focusTarget: function() {
      if (this.caseTab) {
        return this.$refs.case_search;
      } else if (this.textTab) {
        return this.$refs.text_body;
      } else if (this.linkTab) {
        return this.$refs.link_body;
      }
      return null;
    },
    caseTab: function() {
      return this.currentTab === "case";
    },
    textTab: function() {
      return this.currentTab === "text";
    },
    linkTab: function() {
      return this.currentTab === "link";
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
    submitTextForm: function submitTextForm() {
      const data = { from: "Temp", to: "TextBlock", content: this.textContent };
      const url = window.location.href.substr(0, window.location.href.length - 5)
      Axios.patch(url, data).then(
        this.handleSubmitResponse,
        this.handleSubmitErrors
      );
    },
    submitLinkForm: function submitLinkForm() {
      const data = { from: "Temp", to: "Link", url: this.linkTarget };
      const url = window.location.href.substr(0, window.location.href.length - 5)
      Axios.patch(url, data).then(
        this.handleSubmitResponse,
        this.handleSubmitErrors
      );
    },
    selectCase: function(c) {
      const url = window.location.href.substr(0, window.location.href.length - 5)
      const data = { from: "Temp", to: "Case", cap_id: c.id };
      Axios.patch(url, data).then(
        this.handleSubmitResponse,
        this.handleSubmitErrors
      );
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
.type-picker {
  label.textarea {
    width: 100%;
  }
  .search-tabs {
    display: flex;
    flex-direction: row;
    div.search-tab {
      color: black;
    }
  }

  .type-tabs {
    background-position-x: 50%;
    background-position-y: 50%;
    background-size: contain;
    box-sizing: border-box;
    color: rgb(51, 51, 51);
    display: flex;
    flex-direction: row;
    font-size: 14px;
    height: 36px;
    line-height: 20px;
    margin-bottom: 15px;
    margin-left: -15px;
    margin-right: -15px;
    text-size-adjust: 100%;
    width: 100%;
    -webkit-box-direction: normal;
    -webkit-box-orient: horizontal;
    -webkit-tap-highlight-color: rgba(0, 0, 0, 0);

    a.tab {
      border-bottom-style: solid;
      border-bottom-width: 2px;
      box-sizing: border-box;

      cursor: pointer;
      display: block;
      float: none;
      font-size: 14px;
      font-weight: 700;
      height: 26px;
      line-height: 14px;
      margin-bottom: 5px;
      margin: 5px;
      padding: 5px;
      position: relative;
      text-align: center;
      text-decoration-line: none;
      text-decoration-style: solid;
      text-size-adjust: 100%;
      width: 33%;
      color: black;
      text-decoration-color: black;
      &.active,
      &:hover {
        color: rgb(62, 114, 216);
        border-bottom-color: rgb(62, 114, 216);
        text-decoration-color: rgb(62, 114, 216);
      }
    }
    border-bottom: 1px solid black;
  }
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

  a.action.add-resource {
    background-image: url(http://localhost:8080/static/dist/img/add-material.d109215f.svg);
  }
}
</style>
