<template>
  <div>

    <h2>Build your outline.</h2>
    <form @submit.stop.prevent="handleSubmit" class="form-control-group">

      <input
        @paste.prevent.stop="handlePaste"
        v-model="title"
        type="text"
        class="form-control"
        :placeholder="resourceInfo.description"
      />

      <select v-model="resourceInfo" class="resource-type form-control">
        <option
          v-for="option in resourceInfoOptions"
          :key="option.name"
          :value="option.value"
        >
          {{ option.name }}
        </option>
      </select>
      
      <input
        @submit="handleSubmit"
        :value="mode"
        type="submit"
        class="form-control btn btn-primary create-button"
      />
      
      <button
        v-if="mode === SEARCH"
        @click.prevent="
          () => {
            showAdvanced = !showAdvanced;
          }
        "
        class="advanced-search-toggle"
        type="button"
      >
        <span v-if="showAdvanced">Basic search</span>
        <span v-else>Advanced search</span>
      </button>
      <advanced-search
        v-if="mode === SEARCH && showAdvanced"
        @update="(searchData) => (advancedSearch = searchData)"
        :sources="getSources"
        :form-data="advancedSearch"
      ></advanced-search>
    </form>
    <results-form
      @add-doc="onAddDoc"
      :search-results="results"
      :selected-result="selectedResult"
    ></results-form>

    <p class="message" v-if="message">{{ message }}</p>

    <p>
      Use the field above to add section headings, titles for interstitial material, case names, or links to quickly build the outline of your book.
    </p>
    <p>
      You can also paste an outline, or import content from another H2O casebook by pasting a link.
    </p>
  </div>
</template>

<script>
import { createNamespacedHelpers } from "vuex";

import { get_csrf_token } from "../legacy/lib/helpers";
import pp from "libs/text_outline_parser";
import urls from "libs/urls";
import { search, add } from "libs/legal_document_search";

import ResultsForm from "./LegalDocumentSearch/ResultsForm";
import AdvancedSearch from "./LegalDocumentSearch/AdvancedSearch.vue";

const globals = createNamespacedHelpers("globals");
const caseSearch = createNamespacedHelpers("case_search");
const { mapActions } = createNamespacedHelpers("table_of_contents");

const optionTypes = {
  SECTION: {
    resource_type: "Section",
    description:
      "Week One: Introduction to Criminal Law",
  },
  LEGAL_DOCUMENT: {
    description:
      "John v. Smith",
    resource_type: "LegalDocument",
  },
  CUSTOM_CONTENT: {
    description: "Chapter 1",
    resource_type: "TextBlock",
  },
  LINK: {
    description: "http://example.com",
    resource_type: "Link",
  },
  CLONE: {
    description:
      "https://opencasebook.org/casebooks/1/example",
    resource_type: "Clone",
  },
  OUTLINE: {
    description:
      "1. Week One: Introduction to Criminal Law",
    resource_type: "Outline",
  },
};
const options = [
  {
    name: "Section",
    value: optionTypes.SECTION,
  },
  {
    name: "Legal Document",
    value: optionTypes.LEGAL_DOCUMENT,
  },
  {
    name: "Custom Content",
    value: optionTypes.CUSTOM_CONTENT,
  },
  {
    name: "Link",
    value: optionTypes.LINK,
  },
  {
    name: "Clone",
    value: optionTypes.CLONE,
  },
  {
    name: "Outline",
    value: optionTypes.OUTLINE,
  },
];

const initial = function () {
  return {
    title: "",
    resourceInfo: options[0].value,
    resourceInfoOptions: options,
    message: undefined,
    results: undefined,
    selectedResult: undefined,
    ADD: "add",
    SEARCH: "search",
    showAdvanced: false,
    advancedSearch: {
      jurisdiction: undefined,
      beforeDate: undefined,
      afterDate: undefined,
      source: undefined,
    },
  };
};

export default {
  components: {
    ResultsForm,
    AdvancedSearch,
  },
  data: () => ({
    ...initial(),
  }),
  computed: {
    ...globals.mapGetters(["casebook", "section"]),
    ...caseSearch.mapGetters(["getSources"]),
    lineInfo: function () {
      return pp.guessLineType(this.title, this.getSources);
    },
    mode: function () {
      return this.resourceInfo.resource_type === "LegalDocument"
        ? this.SEARCH
        : this.ADD;
    },
  },
  watch: {
    lineInfo: function () {
      switch (this.lineInfo.resource_type) {
        case "Temp": {
          this.resourceInfo = optionTypes.LEGAL_DOCUMENT;
          break;
        }
        case "Link": {
          this.resourceInfo = optionTypes.LINK;
          break;
        }
        case "Clone": {
          this.resourceInfo = optionTypes.CLONE;
          break;
        }
      }
    },
  },
  methods: {
    ...mapActions(["fetch"]),

    bulkAddUrl: urls.url("new_from_outline"),

    resetForm: function () {
      Object.keys(initial()).forEach((k) => (this[k] = initial()[k]));
      this.message = undefined;
      this.selectedResult = undefined;
      this.results = undefined;
    },
    handleSearch: async function () {
      const searchResults = await search(
        this.title,
        this.getSources,
        this.advancedSearch.source,
        this.advancedSearch.jurisdiction,
        this.advancedSearch.beforeDate,
        this.advancedSearch.afterDate
      );
      this.results = searchResults.flat();
    },
    onAddDoc: async function (sourceRef, sourceId) {
      this.added = undefined;
      this.selectedResult = sourceRef.toString();
      this.added = await add(
        this.casebook(),
        this.section(),
        sourceRef,
        sourceId
      );

      this.fetch({ casebook: this.casebook(), subsection: this.section() });
      this.resetForm();
      if (Object.keys(this.added).includes('error')) {
        this.message = this.added.error;
      }
    },
    handleAdd: function () {
      const {
        casebookId,
        ordSlug,
        sectionId,
        sectionOrd,
        titleSlug,
        url,
        userSlug,
      } = this.lineInfo;
      const { title } = this;
      const { resource_type } = this.resourceInfo;
      const data = {
        section: this.section(),
        data: [
          {
            casebookId,
            ordSlug,
            resource_type,
            sectionId,
            sectionOrd,
            title,
            titleSlug,
            url,
            userSlug,
          },
        ],
      };
      this.postData(data);
    },
    handleSubmit: function () {
      if (this.mode === this.SEARCH) {
        return this.handleSearch();
      }
      return this.handleAdd();
    },
    postData: async function (data) {
      const resp = await fetch(
        this.bulkAddUrl({ casebookId: this.casebook() }),
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": get_csrf_token(),
          },
          body: JSON.stringify(data),
        }
      );
      if (resp.ok) {
        const body = await resp.json();

        this.$store.dispatch("table_of_contents/slowMerge", {
          casebook: this.casebook(),
          newToc: body,
        });
        this.resetForm();
      }
      else {
        console.error(resp.status);
        this.message = 'The items could not be added to your casebook because of an error. Our team has been notified. Please retry later.';
      }
    },

    handlePaste: function (event) {
      const pasted = (event.clipboardData || window.clipboardData).getData(
        "text"
      );
      if (pasted.indexOf("\n") >= 0) {
        this.message = "Parsing pasted text";
        const parsed = pp.cleanDocLines(pasted);
        const [parsedJson] = pp.structureOutline(parsed, this.getSources);

        this.postData({ section: this.section(), data: parsedJson.children });
        this.title = "";
      } else {
        this.title += pasted;
      }
    },
  },
};
</script>

<style lang="scss" scoped>
div {
  * {
    margin: 0.5em 0;
  }
  border: 1px dashed black;
  padding: 4rem;

  p:last-of-type {
    margin-bottom: 0;
  }
  h2 {
      margin-top: 0;
      font-size: 130%;
      line-height: 1.6em;
   }
  .message {
    padding: 1em;
    margin: 2em 0;
    background: lightyellow;
    font-weight: bold;
  }
  form {
    display: flex;
    flex-wrap: wrap;
    flex-direction: row;
    margin-bottom: 1em;
    justify-content: space-between;
    gap: 1em;
    
    [type="text"] {
      flex: 1;
    }
    select {
      flex-basis: 30%;
    }
    h3 {
      flex-basis: 65%;
    }
    [type="submit"] {
      text-transform: capitalize;
      flex-basis: 20%;
      font-size: 18px;
    }
    button.advanced-search-toggle {
      background: none;
      border: none;
      text-decoration: underline;
      text-underline-offset: 4px;
      padding: 0;
      flex-basis: 100%;
      text-align: left;
    }
  }
}
</style>

