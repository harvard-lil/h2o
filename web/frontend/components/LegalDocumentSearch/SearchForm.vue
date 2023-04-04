<template>
  <form class="form-group case-search" ref="form" @submit.prevent="search">
    <input
      type="text"
      class="form-control"
      placeholder="Search for a case or section of federal code"
      ref="queryText"
      v-model="query"
    />
    <input
      type="submit"
      class="save-button"
      :value="pending ? 'Searching...' : 'Search'"
      :disabled="pending"
    />

    <button
      class="advanced-search-toggle"
      type="button"
      @click.prevent="toggleAdvanced"
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
            name="after_date"
            type="date"
            class="form-control"
            placeholder="YYYY-MM-DD"
            v-model="after_date"
          />
          <span> - </span>
          <input
            name="before_date"
            type="date"
            class="form-control"
            placeholder="YYYY-MM-DD"
            v-model="before_date"
          />
        </fieldset>
      </label>
      <p v-for="s in getSources" :key="s.id" class="source-description" :data-source-selected="source === s.id">
        {{ s.long_description }}
      </p>
    </fieldset>
  </form>
</template>

<script>
import url from "../../libs/urls";
import { createNamespacedHelpers } from "vuex";

const { mapGetters } = createNamespacedHelpers("case_search");
const api = url.url("search_using");

export default {
  props: {
    toggleReset: Boolean
  },
  data: () => ({
    pending: false,
    query: "",
    jurisdictions: [
      { val: "ala", name: "Alabama" },
      { val: "alaska", name: "Alaska" },
      { val: "am-samoa", name: "American Samoa" },
      { val: "ariz", name: "Arizona" },
      { val: "ark", name: "Arkansas" },
      { val: "cal", name: "California" },
      { val: "colo", name: "Colorado" },
      { val: "conn", name: "Connecticut" },
      { val: "dakota-territory", name: "Dakota Territory" },
      { val: "dc", name: "District of Columbia" },
      { val: "del", name: "Delaware" },
      { val: "fla", name: "Florida" },
      { val: "ga", name: "Georgia" },
      { val: "guam", name: "Guam" },
      { val: "haw", name: "Hawaii" },
      { val: "idaho", name: "Idaho" },
      { val: "ill", name: "Illinois" },
      { val: "ind", name: "Indiana" },
      { val: "iowa", name: "Iowa" },
      { val: "kan", name: "Kansas" },
      { val: "ky", name: "Kentucky" },
      { val: "la", name: "Louisiana" },
      { val: "mass", name: "Massachusetts" },
      { val: "md", name: "Maryland" },
      { val: "me", name: "Maine" },
      { val: "mich", name: "Michigan" },
      { val: "minn", name: "Minnesota" },
      { val: "miss", name: "Mississippi" },
      { val: "mo", name: "Missouri" },
      { val: "mont", name: "Montana" },
      { val: "native-american", name: "Native American" },
      { val: "navajo-nation", name: "Navajo Nation" },
      { val: "nc", name: "North Carolina" },
      { val: "nd", name: "North Dakota" },
      { val: "neb", name: "Nebraska" },
      { val: "nev", name: "Nevada" },
      { val: "nh", name: "New Hampshire" },
      { val: "nj", name: "New Jersey" },
      { val: "nm", name: "New Mexico" },
      { val: "n-mar-i", name: "Northern Mariana Islands" },
      { val: "ny", name: "New York" },
      { val: "ohio", name: "Ohio" },
      { val: "okla", name: "Oklahoma" },
      { val: "or", name: "Oregon" },
      { val: "pa", name: "Pennsylvania" },
      { val: "pr", name: "Puerto Rico" },
      { val: "ri", name: "Rhode Island" },
      { val: "sc", name: "South Carolina" },
      { val: "sd", name: "South Dakota" },
      { val: "tenn", name: "Tennessee" },
      { val: "tex", name: "Texas" },
      { val: "tribal", name: "Tribal jurisdictions" },
      { val: "uk", name: "United Kingdom" },
      { val: "us", name: "United States" },
      { val: "utah", name: "Utah" },
      { val: "va", name: "Virginia" },
      { val: "vi", name: "Virgin Islands" },
      { val: "vt", name: "Vermont" },
      { val: "wash", name: "Washington" },
      { val: "wis", name: "Wisconsin" },
      { val: "w-va", name: "West Virginia" },
      { val: "wyo", name: "Wyoming" },
    ],
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
    toggleReset: function() {
      this.$refs.form.reset()
    }
  },
  methods: {
    search: async function () {
      if (!this.query) {
        return;
      }

      this.pending = true;
      const sources = [];
      const sourceDetail = this.getSources.filter((s) =>
        this.source ? s.id === this.source : true
      );

      let order = 0; // Sources will come back ordered in "priority order", which we want to retain
      for (const { id, name } of sourceDetail) {
        const url =
          api({ sourceId: id }) +
          "?" +
          new URLSearchParams({
            q: this.query,
            jurisdiction: this.jurisdiction || "",
            before_date: this.before_date || "",
            after_date: this.after_date || "",
          });
        sources.push({ url, id, name, order });
        order += 1;
      }
      const searchResults = await Promise.all(
        sources.map(async (source) => {
          const { url, id, name, order } = source;
          return fetch(url)
            .then((r) => r.json())
            .then((r) => {
              const { results } = r;
              return results.map((row) => {
                row.id = row.id.toString(); // normalize IDs from the API to strings
                return {
                  name,
                  sourceId: id,
                  sourceOrder: order,
                  ...row,
                };
              });
            });
        })
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
