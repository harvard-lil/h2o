<template>
  <div>
    <form @submit.stop.prevent="handleSubmit" class="form-control-group">
      <h3>
        Add an individual resource or a list of items by pasting them into the
        field below.
      </h3>

      <input
        @paste.prevent.stop="handlePaste"
        v-model="title"
        type="text"
        class="form-control"
        placeholder="'Chapter 1' or 'http://example.com' or 'John v. Smith'"
      />

      <input
        @submit="handleSubmit"
        :value="mode"
        type="submit"
        class="form-control btn btn-primary create-button"
      />

      <section>
        <p class="resource-type-description">{{ resourceInfo.description }}</p>

        <p>
          To learn more, review our
          <a href="https://about.opencasebook.org/making-casebooks/#quick-add"
            >quick add documentation.</a
          >
        </p>
      </section>

      <fieldset class="resource-type-group">
        <fieldset v-for="option in resourceInfoOptions" :key="option.name">
          <input
            v-model="resourceInfo"
            :value="option.value"
            :id="option.value.resource_type"
            type="radio"
          />
          <label :for="option.value">{{ option.name }}</label>
        </fieldset>
      </fieldset>


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

    <p>{{ waitingFor }}</p>
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
      "Group your casebook into discrete sections to organize the material.",
  },
  LEGAL_DOCUMENT: {
    description:
      "Search our library of US case law and code for documents to automatically import.",
    resource_type: "LegalDocument",
  },
  CUSTOM_CONTENT: {
    description: "Add your own written commentary or chapters.",
    resource_type: "TextBlock",
  },
  LINK: {
    description: "Paste a link to an external resource or article.",
    resource_type: "Link",
  },
  CLONE: {
    description:
      "Paste a link to a resource in another casebook to automatically import it into your own.",
    resource_type: "Clone",
  },
  OUTLINE: {
    description:
      "Paste an outline of your table of contents and H2O will automatically create a draft casebook based on it.",
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
    waitingFor: undefined,
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
      this.waitingFor = undefined;
      this.selectedResult = undefined;
      this.results = undefined;
    },
    handleSearch: async function () {
      console.log("hi");
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

      const body = await resp.json();

      this.$store.dispatch("table_of_contents/slowMerge", {
        casebook: this.casebook(),
        newToc: body,
      });
      this.resetForm();
    },

    handlePaste: function (event) {
      const pasted = (event.clipboardData || window.clipboardData).getData(
        "text"
      );
      if (pasted.indexOf("\n") >= 0) {
        this.waitingFor = "Parsing pasted text";
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
  border: 1px dashed black;
  padding: 4rem;

  p:last-of-type {
    margin-bottom: 0;
  }
  h3 {
    margin: 0;
    font-size: 130%;
    line-height: 1.6em;
  }

  form {
    display: flex;
    flex-wrap: wrap;
    flex-direction: row;
    margin-bottom: 1em;
    justify-content: space-between;
    gap: 2em;

    [type="text"] {
      flex-basis: 75%;
    }
    label {
      padding: 0 0 0 1rem;
      font-size: 14px;
      font-weight: normal;
    }

    fieldset {
      margin: 0;
    }
    .resource-type-group {
      columns: 2;
    }
    section {
      flex: 2;
    }
    h4 {
      width: 100%;
      font-size: 14px;

      text-align: center;
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

