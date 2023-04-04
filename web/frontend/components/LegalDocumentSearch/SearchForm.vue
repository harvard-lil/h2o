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
      @click.prevent="toggleAdvanced"    
      class="advanced-search-toggle"
      type="button"
    >
      <span v-if="showAdvanced">Basic search</span>
      <span v-else>Advanced search</span>
    </button>

    <fieldset v-if="showAdvanced" class="advanced-search">
      <label>
        Source:
        <select class="form-control" v-model="source">
          <option :value="undefined">All sources</option>
          <option
            v-for="source in getSources"
            :value="source.id"
            :key="source.id"
          >
            {{ source.name }}
          </option>
        </select>
      </label>
      <label>
        Jurisdiction:
        <select class="form-control" v-model="jurisdiction" name="jurisdiction">
          <option :value="undefined">All jurisdictions</option>
          <option v-for="j in jurisdictions" :value="j.val" :key="j.val">
            {{ j.name }}
          </option>
        </select>
      </label>
      <label>
        Decision Date
        <fieldset>
          <input
            v-model="after_date"
            name="after_date"
            type="date"
            class="form-control"
            placeholder="YYYY-MM-DD"
          />
          <span> - </span>
          <input
            v-model="before_date"          
            name="before_date"
            type="date"
            class="form-control"
            placeholder="YYYY-MM-DD"
          />
        </fieldset>
      </label>
      <p
        v-for="s in getSources"
        :key="s.id"
        :data-source-selected="source === s.id"
        class="source-description"
      >
        {{ s.long_description }}
      </p>
    </fieldset>
  </form>
</template>

<script>
import { createNamespacedHelpers } from "vuex";
import { search, jurisdictions } from "../../libs/legal_document_search";

const { mapGetters } = createNamespacedHelpers("case_search");

export default {
  props: {
    toggleReset: Boolean
  },
  data: () => ({
    pending: false,
    query: "",
    jurisdictions,
    showAdvanced: false,
    jurisdiction: undefined,
    before_date: undefined,
    after_date: undefined,
    source: undefined,
  }),
  computed: {
    ...mapGetters(["getSources"]),
  },
  mounted() {
    this.$refs.queryText.focus();
  },
  watch: {
    toggleReset: function () {
      this.$refs.form.reset();
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
        this.source,
        this.jurisdiction,
        this.before_date,
        this.after_date
      );

      this.pending = false;
      
      this.$emit("search-results", searchResults.flat());
    },
    toggleAdvanced: function () {
      this.showAdvanced = !this.showAdvanced;
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
  .advanced-search {
    display: flex;
    gap: 1em;
    flex-wrap: wrap;
    margin: 1em 0;
    flex-basis: 100%;

    label {
      width: 100%;
      line-height: 2em;

      & * {
        font-weight: normal;
      }
      select {
        padding-left: 0.5em;
      }
    }
    & > label {
      flex-basis: 24%;
    }
    & > label:last-of-type {
      flex-basis: 48%;
      fieldset {
        display: flex;
        gap: 1em;
        align-items: center;
        justify-content: center;
        input {
          padding: 3px;
          text-indent: 10px;
        }
      }
    }

    p.source-description {
      flex-basis: 100%;
      display: none;
    }
    p.source-description[data-source-selected] {
      display: block;
    }
  }
}
</style>
