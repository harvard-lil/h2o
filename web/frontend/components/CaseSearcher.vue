<template>
  <div class="search-results" id="case-search-results">
    <form class="case-search">
      <div class="form-control-group">
        <label style="width:66%;">
          {{searchLabel}}
          <input
            id="case_search"
            ref="case_search"
            class="form-control"
            name="q"
            type="text"
            placeholder="Search for a case to import"
            v-model="passThrough"
          />
        </label>
        <input
          style="margin-top:-4px;"
          class="search-button"
          type="submit"
          value="Search"
          v-on:click.stop.prevent="runCaseSearch"
        />
      </div>
      <div v-if="!showingLimits">
        <a v-on:click.stop.prevent="showLimits">Limit search by date range and/or jurisdiction</a>
      </div>
      <div class="form-control-group" v-else>
        <a v-on:click.stop.prevent="hideLimits">Disable limits on search</a>
        <div>
          <label>
            Jurisdiction:
            <select class="form-control-sm" v-model="jurisdiction" name="jurisdiction">
              <option :value="j.val" v-for="j in jurisdictions" :key="j.val">{{j.name}}</option>
            </select>
          </label>
          <label class="small-gap">
            Decision Date
            <input
              name="after_date"
              type="date"
              class="form-control-sm"
              placeholder="YYYY-MM-DD"
              v-model="after_date"
              @blur="reformatDates"
            />
          </label>
          <label class="wee-gap">
            -
            <input
              name="before_date"
              type="date"
              class="form-control-sm"
              placeholder="YYYY-MM-DD"
              v-model="before_date"
              @blur="reformatDates"
            />
          </label>
        </div>
      </div>
    </form>
  </div>
</template>

<script>
import _ from "lodash";
import { createNamespacedHelpers } from "vuex";
const { mapActions } = createNamespacedHelpers("case_search");

const jurisdictions = [
  { val: "", name: "All Jurisdictions" },
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
  { val: "tribal", name: "Tribal Jurisdictions" },
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
  props: ["searchOnTop", "canCancel", "value", "searchLabel"],
  data: () => ({
    jurisdictions,
    showingLimits: false
  }),
  methods: {
    ...mapActions(["fetch"]),
    showLimits: function() {
      this.showingLimits = true;
      this.updateValue(this.value);
    },
    hideLimits: function() {
      this.showingLimits = false;
      this.updateValue(this.value);
    },
    reformatDates: function() {
      function completeDates(v, k) {
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
      this.$emit('input', newValue);
      return newValue;
    },
    runCaseSearch: function runCaseSearch() {
      const searchQ = this.reformatDates();
      if (searchQ.query !== "") {
        this.fetch(searchQ);
      }
    },
    emitCancel: function() {
      this.$emit("cancel", null);
    },
    emitChoice: function(c) {
      this.$emit("choose", c);
    },
    updateValue: function(newVal) {
      this.$emit("input", this.cleaned(newVal));
    },
    cleaned: function(val) {
      const validKeys = this.showingLimits
        ? ["query", "jurisdiction", "before_date", "after_date"]
        : ["query"];
      return _.pickBy(
        val,
        (v, k) => v && v !== "" && validKeys.indexOf(k) > -1
      );
    }
  },
  computed: {
    displayedSearchLabel: function() {
      return this.searchLabel || "";
    },
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
    }
  }
};
</script>

<style lang="scss" scoped>
.small-gap {
  margin-left: 2rem;
}
.wee-gap {
  margin-left: 1rem;
}
</style>
