<template>
  <div>
    <h3>
      Add an individual resource or a list of items by pasting them into the
      field below.
    </h3>

    <form
      @submit.stop.prevent="handleSubmit"
      class="form-control-group"
    >
      <input
        @paste.prevent.stop="handlePaste"
        v-model="title"
        type="text"
        class="form-control"
        placeholder="Enter case, heading, link, or outline here"
      />
      <select v-model="resource_info" class="resource-type form-control">
        <option
          v-for="option in resource_info_options"
          :key="option.k"
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
    </form>
    <results-form
      @add-doc="onAddDoc"
      :search-results="results"
      :selected-result="selectedResult"
    ></results-form>
    
    <p>{{ waitingFor }}</p>

    <p>
      To learn more, review our
      <a href="https://about.opencasebook.org/making-casebooks/#quick-add"
        >quick add documentation.</a
      >
    </p>
  </div>
</template>

<script>
import _ from "lodash";
import { createNamespacedHelpers } from "vuex";

import ResultsForm from "./LegalDocumentSearch/ResultsForm";

import Axios from "../config/axios";
import pp from "libs/text_outline_parser";
import urls from "libs/urls";
import { search, add } from "libs/legal_document_search";

const globals = createNamespacedHelpers("globals");
const caseSearch = createNamespacedHelpers("case_search");
const { mapActions } = createNamespacedHelpers("table_of_contents");

const optionsWithoutCloning = [
  { name: "Section", value: { resource_type: "Section" }, k: 0 },
  { name: "Legal Document", value: { resource_type: "LegalDocument" }, k: 1 },
  { name: "Custom Content", value: { resource_type: "TextBlock" }, k: 2 },
  { name: "Link", value: { resource_type: "Link" }, k: 3 },
];

const data = function () {
  return {
    title: "",
    resource_info: optionsWithoutCloning[0].value,
    resource_info_options: optionsWithoutCloning,
  };
};
const ADD = "add";
const SEARCH = "search";

export default {
  components: {
    ResultsForm,
  },
  props: [],
  data: function () {
    return {
      ...data(),
      stats: {},
      waitingFor: undefined,
      results: undefined,
      selectedResult: undefined,
    };
  },
  directives: {},
  computed: {
    ...globals.mapGetters(["casebook", "section"]),
    ...caseSearch.mapGetters(["getSources"]),
    totalIdentified: function () {
      return _.values(this.stats).reduce((a, b) => a + b, 0);
    },
    lineInfo: function () {
      return pp.guessLineType(this.title, this.getSources);
    },
    desiredOrdinal: function () {
      const ordinalGuess = this.title.match(/^[0-9]+(\.[0-9])* /);
      if (ordinalGuess) {
        return ordinalGuess[0];
      }
      return undefined;
    },
    mode: function () {
      return this.resource_info.resource_type === "LegalDocument"
        ? SEARCH
        : ADD;
    },
  },
  watch: {
    lineInfo: function () {
      if (this.lineInfo.resource_type === "Temp") {
        this.resource_info = { resource_type: "LegalDocument" };
      }
    },
  },
  methods: {
    ...mapActions(["fetch"]),

    bulkAddUrl: urls.url("new_from_outline"),
    resetForm: function () {
      let resets = data();
      _.keys(resets).forEach((k) => {
        this[k] = resets[k];
      });
      this.waitingFor = undefined;
      this.manualResourceType = false;
      this.selectedResult = undefined;
      this.results = undefined;
    },
    handleSearch: async function () {
      const searchResults = await search(this.title, this.getSources);
      this.results = searchResults.flat();
      this.title = "";
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
      this.resetForm();
      this.fetch({ casebook: this.casebook(), subsection: this.section() });
    },
    handleAdd: function () {
      let desiredSubset = _.pick(this.resource_info, [
        "resource_type",
        "url",
        "casebookId",
        "resource_id",
        "sectionId",
        "sectionOrd",
        "userSlug",
        "titleSlug",
        "ordSlug",
      ]);
      let nodeData = { ...desiredSubset, title: this.title };

      if (nodeData.resource_type === "Unknown") {
        nodeData.resource_type = "Temp";
      }
      if (nodeData.resource_type === "Link") {
        if (!nodeData.url) {
          nodeData.url = nodeData.title;
        }
        nodeData.title = undefined;
      }
      const data = {
        section: this.section(),
        data: [nodeData],
      };
      this.postData(data);
    },
    handleSubmit: function () {
      if (this.mode === SEARCH) {
        return this.handleSearch();
      }
      return this.handleAdd();
    },
    postData: function (data) {
      return Axios.post(
        this.bulkAddUrl({ casebookId: this.casebook() }),
        data
      ).then(this.handleSuccess, this.handleFailure);
    },
    handleSuccess: function (resp) {
      this.$store.dispatch("table_of_contents/slowMerge", {
        casebook: this.casebook(),
        newToc: resp.data,
      });
      this.resetForm();
    },
    handleFailure: function (resp) {
      console.error(resp);
    },
    handlePaste: function (event) {
      const pasted = (event.clipboardData || window.clipboardData).getData(
        "text"
      );
      if (pasted.indexOf("\n") >= 0) {
        this.waitingFor = "Parsing pasted text";
        const parsed = pp.cleanDocLines(pasted);
        const [parsedJson, stats] = pp.structureOutline(parsed, this.getSources);
        _.keys(stats).map((k) => {
          this.stats[k] = _.get(this.stats, k, 0) + stats[k];
        });
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
    margin: .5em 0;
  }
  border: 1px dashed black;
  padding: 4rem;

  h3 {
    margin-top: 0;
    font-size: 130%;
  }

  p:last-of-type {
    margin-bottom: 0;
  }

  form {
    display: flex;
    flex-direction: row;
    margin-bottom: 1em;
    *:not(:first-child) {
      margin-left: 1rem;
    }
    select {
      flex-basis: 50%;
    }
    [type="submit"] {
      text-transform: capitalize;
      flex-basis: 20%;      
      font-size: 18px;
    }
  }

}
</style>

