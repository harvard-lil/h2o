<template>
  <div>
    <case-results :queryObj="searchOptions" @choose="selectCase"></case-results>
    <case-searcher v-model="searchOptions"></case-searcher>
  </div>
</template>

<script>
import CaseSearcher from "../CaseSearcher";
import CaseResults from "../CaseResults";
import Axios from "../../config/axios";
import pp from "../../libs/text_outline_parser";

export default {
  components: {
    CaseSearcher,
    CaseResults
  },
  props: ["item"],
  data: () => ({ searchOptions: { query: "" } }),
  computed: {
    casebook: function() {
      return this.$store.getters["globals/casebook"]();
    },
    section: function() {
      return this.$store.getters["globals/section"]();
    },
    rootNode: function() {
      return this.section || this.casebook;
    },
    url: function() {
      return this.editing ? this.item.edit_url : this.item.url;
    }
  },
  methods: {
    selectCase: function(c) {
      const url = this.item.url;
      const data = { from: "Temp", to: "Case", cap_id: c.id };
      Axios.patch(url, data).then(
        this.handleSubmitResponse,
        this.handleSubmitErrors
      );
    },
    selectText: function() {
      const url = this.item.url;
      const data = { from: "Temp", to: "TextBlock", content: "TBD" };
      Axios.patch(url, data).then(
        this.handleSubmitResponse,
        this.handleSubmitErrors
      );
    },
    extraErrorHandler: function(error) {
      console.error(error);
    },
    handleSubmitResponse: function handleSubmitResponse(response) {
      this.$store.dispatch("table_of_contents/clearAudit", {
        id: this.item.id
      });
      this.$store.dispatch("table_of_contents/fetch", {
        casebook: this.casebook,
        subsection: this.section
      });
    },
    handleSubmitErrors: function handleSubmitErrors(error) {
      console.error(error);
    }
  },
  mounted: function() {
    this.searchOptions.query = pp.extractCaseSearch(this.item.title);
  }
};
</script>

<style lang="scss" scoped>
.listing.resource.temporary {
  outline: 2px solid red;
}
</style>