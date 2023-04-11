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
    <p class="message" v-if="message">{{ message }}</p>
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
    toggleReset: false,
    message: undefined,
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
      this.results = res;
    },
    onAddDoc: async function (sourceRef, sourceId) {
      this.added = undefined;
      this.selectedResult = sourceRef.toString();
      this.added = await add(this.casebook, this.section, sourceRef, sourceId)
      if (Object.keys(this.added).includes('error')) {
        this.message = this.added.error;
      }
      this.fetch({ casebook: this.casebook, subsection: this.section });
    },
  },
};
</script>
<style lang="scss" scoped>
  .message {
    padding: 1em;
    margin: 2em 0;
    background: lightyellow;
    font-weight: bold;
  }
</style>