<template>
  <form class="form-group case-search" ref="form" @submit.prevent="search">
    <input
      v-model="query"
      type="text"
      class="form-control"
      placeholder="Search for a case or section of federal code"
      ref="queryText"
    />
    <input
      :value="pending ? 'Searching...' : 'Search'"
      :disabled="pending"
      type="submit"
      class="save-button"
    />

    <button
      @click.prevent="showAdvanced = !showAdvanced"
      class="advanced-search-toggle"
      type="button"
    >
      <span v-if="showAdvanced">Basic search</span>
      <span v-else>Advanced search</span>
    </button>

    <advanced-search
      v-if="showAdvanced"
      @update="(searchData) => (advancedSearch = searchData)"
      :sources="getSources"
      :form-data="advancedSearch"
    ></advanced-search>
  </form>
</template>

<script>
import { createNamespacedHelpers } from "vuex";
import { search } from "../../libs/legal_document_search";
import AdvancedSearch from "./AdvancedSearch.vue";

const { mapGetters } = createNamespacedHelpers("case_search");

export default {
  components: { AdvancedSearch },
  props: {
    toggleReset: Boolean,
  },
  data: () => ({
    pending: false,
    query: "",
    showAdvanced: false,
    advancedSearch: {
      jurisdiction: undefined,
      beforeDate: undefined,
      afterDate: undefined,
      source: undefined,
    },
  }),
  computed: {
    ...mapGetters(["getSources"]),
  },
  mounted() {
    this.$refs.queryText.focus();
  },
  watch: {
    toggleReset: function () {
      this.query = "";
      Object.keys(this.advancedSearch).forEach(
        (k) => (this.advancedSearch[k] = undefined)
      );
    },
  },
  methods: {
    search: async function () {
      if (!this.query) {
        return;
      }
      this.pending = true;
      const searchResults = await search(
        this.query,
        this.getSources,
        this.advancedSearch.source,
        this.advancedSearch.jurisdiction,
        this.advancedSearch.beforeDate,
        this.advancedSearch.afterDate
      );

      this.pending = false;

      this.$emit("search-results", searchResults.flat());
    },

  },
};
</script>

<style lang="scss" scoped>
form {
  display: flex;
  flex-wrap: wrap;
  margin: 30px auto 30px 0 !important;
  justify-content: space-between;
  align-items: center;
  gap: 1em;

  input {
    margin: 0 !important;
    height: 52px;
  }
  input[type="text"] {
    flex-basis: 66%;
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
</style>
