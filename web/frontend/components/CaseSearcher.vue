<template>
<div class="search-results">
  <form class="case-search">
    <div class="form-control-group">

      <label class="case-search-input">
        <input
          id="case_search"
          ref="case_search"
          class="form-control"
          name="q"
          type="text"
          placeholder="Search for a case or section of federal code"
          v-model="passThrough"
          />
      </label>
      <input
        type="submit"
        class="search-button btn btn-primary"

        :value="pendingSearch ? 'Searching...' : 'Search'" :disabled="pendingSearch"
        v-on:click.stop.prevent="runCaseSearch"
        />

    <div class="form-block">
      <div v-if="!showingLimits">
        <button class="advanced-search-toggle" v-on:click.stop.prevent="showLimits">Advanced search options</button>
      </div>
      <div v-else>
        <button class="advanced-search-toggle" v-on:click.stop.prevent="hideLimits">Basic search</button>

        <div class="advanced-search">
          <div>
            <label>
              Source:
                <select class="form-control" v-model="searchLimit">
                  <option :value="null">All sources</option>
                  <option :value="source" v-for="source in getSources" :key="source.id">{{source.name}}</option>
                </select>
            </label>

          </div>
        <div>
          <label>
            Jurisdiction:
            <select class="form-control" v-model="jurisdiction" name="jurisdiction">
              <option :value="j.val" v-for="j in jurisdictions" :key="j.val">{{j.name}}</option>
            </select>
          </label>
        </div>
        <label>
            Decision Date
            <div class="date-row form-control-inline">
                <input
                  name="after_date"
                  type="date"
                  class="form-control"
                  placeholder="YYYY-MM-DD"
                  v-model="after_date"
                  @blur="reformatDates"
                  />
              <span> - </span>
              <input
                  name="before_date"
                  type="date"
                  class="form-control"
                  placeholder="YYYY-MM-DD"
                  v-model="before_date"
                  @blur="reformatDates"
                  />
            </div>
        </label>
        <p>
          {{searchLimit ? searchLimit.long_description : ''}}
        </p>
      </div>
    </div>
    </div>
  </div>
  </form>
</div>
</template>

<script>
import _ from "lodash";
import pp from "libs/text_outline_parser";
import { createNamespacedHelpers } from "vuex";
const { mapActions, mapGetters } = createNamespacedHelpers("case_search");

const jurisdictions = [
  { val: "", name: "All jurisdictions" },
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
  { val: "wyo", name: "Wyoming" }
];

export default {
  props: ["value"],
  data: () => ({
    jurisdictions,
    pendingSearch: false,
    showingLimits: false,
    chosenSource: null,
    overrideSource: false
  }),
  watch: {
    passThrough: function(newVal) {
      
    }
  },
  methods: {
    ...mapActions(["fetchForAllSources", "fetchForSource", "fetchSources"]),
    showLimits: function() {
      this.showingLimits = true;
      this.updateValue(this.value);
    },
    hideLimits: function() {
      this.showingLimits = false;
      this.updateValue(this.value);
    },
    reformatDates: function() {
      function completeDates(v, k) { // FIXME this should really use a date library
        const dateRex = /(?<year>[0-9]{4})-?(?<month>[0-9]{1,2})?-?(?<day>[0-9]{1,2})?/;
        if (k === "after_date") {
          let [_, year, month, day] = dateRex.exec(v);
          if (!year) {
            return undefined;
          }
          month = month || "01";
          month = month.length == 1 ? "0" + month : month;
          day = day || "01";
          day = day.length == 1 ? "0" + day : day;
          return `${year}-${month}-${day}`;
        } else if (k === "before_date") {
          let [_, year, month, day] = dateRex.exec(v);
          if (!year) {
            return undefined;
          }
          if (!month) {
            return `${year}-12-31`;
          }
          month = month.length == 1 ? "0" + month : month;
          if (!day) {
            const monthDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]; 
            let iMonth = parseInt(month) - 1;
            iMonth = iMonth > 11 ? 11 : iMonth;
            return `${year}-${month}-${monthDays[iMonth]}`;
          }
          day = day.length == 1 ? "0" + day : day;
          return `${year}-${month}-${day}`;
        } else {
          return v;
        }
      }
      const newValue = _.mapValues(this.cleanQuery, completeDates);
      this.$emit("input", newValue);
      return newValue;
    },
    runCaseSearch: function runCaseSearch() {
      const searchQ = this.reformatDates();
      if (searchQ.query !== "") {
        if (this.showingLimits && searchQ.searchLimit) {
          this.fetchForSource({queryObj: searchQ, source: this.searchLimit})
        } else {
          this.fetchForAllSources({queryObj: searchQ});
        }
        this.$emit("input", searchQ)
      }
    },
    emitCancel: function() {
      this.$emit("cancel", null);
    },
    emitChoice: function(c) {
      this.$emit("choose", c);
    },
    guessSource: function(query) {
      let {guesses} = pp.guessLineType(query, this.getSources);
      if (guesses && guesses.length > 0) {
        this.chosenSource = this.getSources[guesses[0].source.sourceIndex];
      } else {
        this.chosenSource = this.getSources[0]
      }
    },
    updateValue: function(newVal) {
      if (!this.showingLimits) {
        this.guessSource(newVal.query);
      }
      this.$emit("input", this.cleaned(newVal));
    },
    cleaned: function(val) {
      const validKeys = this.showingLimits
            ? ["query", "jurisdiction", "before_date", "after_date", "searchLimit"]
            : ["query"];
      return _.pickBy(
        val,
        (v, k) => v && v !== "" && validKeys.indexOf(k) > -1
      );
    }
  },
  computed: {
    ...mapGetters(['getSources']),

    cleanQuery: function() {
      const data = this.cleaned(this.value);
      if (data.query) {
        return data;
      }
      return { query: "" };
    },
    after_date: {
      get: function() {
        return this.value.after_date;
      },
      set: function(val) {
        this.updateValue({ ...this.value, after_date: val });
      }
    },
    before_date: {
      get: function() {
        return this.value.before_date;
      },
      set: function(val) {
        this.updateValue({ ...this.value, before_date: val });
      }
    },
    jurisdiction: {
      get: function() {
        return this.value.jurisdiction || "";
      },
      set: function(val) {
        this.updateValue({ ...this.value, jurisdiction: val });
      }
    },
    passThrough: {
      get: function() {
        return this.value.query;
      },
      set: function(val) {
        this.updateValue({ ...this.value, query: val });
      }
    },
    searchLimit: {
      get: function() {
        return this.value.searchLimit || null;
      },
      set: function(val) {
        this.updateValue({ ...this.value, searchLimit: val });
      }
    }

  },
  mounted: function() {
    this.guessSource(this.value.query);
  }
};
</script>

<style lang="scss" scoped>
.search-results {
  margin: auto;
}
.search-button {
    margin-left: 2rem;
}
.date-row {
    display: grid;
    grid-template-columns: auto 24px auto;
    align-items: center;
    span {
        text-align: center;
    }
    input {
      padding-bottom: 4px;
      padding-top: 3px;
    }
}

.form-control-group {
  display: flex;
  flex-wrap: wrap;
  margin: auto;
  justify-content: space-between;
  align-items: center;
  gap: 1em;
    
  .case-search-input {
    flex-basis: 66%;
    margin: 0;
  }
  input[type="submit"] {
      margin: 0;
  }

  .form-block {
    flex-basis: 100%;
  }
  button.advanced-search-toggle {
    background: none;
    border: none;
    text-decoration: underline;
    text-underline-offset: 4px;
    padding: 0;
  }
  .advanced-search {
    display: flex;
    gap: 1em;
    flex-wrap: wrap;
    margin: 1em 0;

    label {
      width: 100%;
      line-height: 2em;
      
      & * {
        font-weight: normal;
      }
      select {
        padding-left: .5em;
      }
    }
    & > div {
      flex-basis: 24%;
    }
    & > label {
      flex-basis: 48%;
    }
    .form-control {
      font-size: 16px;
      height: initial;
    }
    p {
      flex-basis: 100%;
    }
  }
}
</style>
