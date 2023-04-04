<template>
  <section>
    <search-form @search-results="onSearchResults" :toggle-reset="toggleReset" />
    <results-form
      @add-doc="onAddDoc"
      @reset-search="resetSearch"
      @close="$emit('close')"
      :search-results="results"
      :added="added"
      :selected-result="selectedResult"
    />
  </section>
</template>

<script>
import SearchForm from "./SearchForm";
import ResultsForm from "./ResultsForm";
import { createNamespacedHelpers } from "vuex";
import { add } from "../../libs/legal_document_search";

const { mapActions } = createNamespacedHelpers("table_of_contents");

export default {
  props: {
    casebook: String,
    section: String,
  },
  components: {
    SearchForm,
    ResultsForm,
  },
  data: () => ({
    results: undefined,
    added: undefined,
    selectedResult: undefined,
    toggleReset: false
  }),
  methods: {
    ...mapActions(["fetch"]),

    resetSearch: function () {
      this.results = undefined;
      this.added = undefined;
      this.selectedResult = undefined;
      this.toggleReset = !this.toggleReset;
    },
    onSearchResults: function (res) {
      this.resetSearch();
      this.results = res;
    },
    onAddDoc: async function (sourceRef, sourceId) {
      this.added = undefined;
      this.selectedResult = sourceRef.toString();
      this.added = await add(this.casebook, this.section, sourceRef, sourceId)
      this.fetch({ casebook: this.casebook, subsection: this.section });
    },
  },
};
</script>
