<template>
  <section>
    <search-form @search-results="onSearchResults" />
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
import url from "../../libs/urls";
import { get_csrf_token } from "../../legacy/lib/helpers";
import { createNamespacedHelpers } from "vuex";

const api = url.url("legal_document_resource_view");
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
  }),
  methods: {
    ...mapActions(["fetch"]),

    resetSearch: function () {
      this.results = undefined;
      this.added = undefined;
      this.selectedResult = undefined;
    },
    onSearchResults: function (res) {
      this.resetSearch();
      this.results = res;
    },
    onAddDoc: async function (sourceRef, sourceId) {
      this.added = undefined;
      this.selectedResult = sourceRef.toString();
      const resp = await fetch(api({ casebookId: this.casebook }), {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": get_csrf_token(),
        },
        body: JSON.stringify({
          source_id: sourceId,
          source_ref: sourceRef,
          section_id: this.section,
        }),
      });
      const body = await resp.json();
      this.added = {
        resourceId: body.resource_id,
        redirectUrl: body.redirect_url,
        sourceRef,
      };
      this.fetch({ casebook: this.casebook, subsection: this.section });
    },
  },
};
</script>
