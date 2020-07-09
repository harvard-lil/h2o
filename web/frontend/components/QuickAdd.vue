<template>
  <div id="quick-add">
    <div class="form-control-group">
      <form @submit.stop.prevent="handleSubmit">
        <div class="form">
          <div class="form-control-group inline-search">
            <input
              type="text"
              class="form-control"
              v-model="title"
              name="addcontent"
              @paste.prevent.stop="handlePaste"
              placeholder="Enter title here"
            />
            <select v-model="resource_type" class="resource-type form-control">
              <option value="Section">Section</option>
              <option value="Case">Case</option>
              <option value="Text">Text</option>
              <option value="Link">Link</option>
            </select>
            <input
              type="submit"
              class="form-control btn btn-primary create-button"
              value="Add"
              @submit="handleSubmit"
            />
          </div>
        </div>
      </form>
      <div class="stats" v-if="totalIdentified > 0">
        Added {{stats.sections}} sections, {{stats.cases}} cases, {{stats.links}} links, and {{stats.texts}} texts.
      </div>
    </div>
    <div class="advice">
      <span>Quickly add entries to your table of contents above</span>
      <ul>
        <li>We'll try to automatically detect the type of content you're adding</li>
        <li>You can copy+paste a table of contents from a word doc or PDF and we'll try to preserve the structure</li>
      </ul>
    </div> 
  </div>
</template>

<script>
import _ from "lodash";
import LoadingSpinner from "./LoadingSpinner";
import Axios from "../config/axios";
import pp from "libs/text_outline_parser";

const data = function() {
    return {
      title: "",
      resource_type: "Section",
    };
  };
const caseSearchDelay = 1000;
export default {
  components: {
    LoadingSpinner // eslint-disable-line vue/no-unused-components
  },
  props: ["casebook", "section", "rootOrdinals"],
  data: function() {
    return {...data(),stats:{cases:0, texts:0, links:0,sections:0}};
  },
  directives: {},
  computed: {
    totalIdentified: function() {
      return _.values(this.stats).reduce((a, b) => a + b, 0);
    },
    lineInfo: function() {
      return pp.guessLineType(this.title);
    },
    desiredOrdinal: function() {
      const startOrdinal = /^[0-9]+(\.[0-9])* /;
      const ordinalGuess = this.title.match(startOrdinal);
      if (ordinalGuess) {
        return ordinalGuess[0];
      }
      return undefined;
    }
  },
  watch: {
    resource_type: function(newVal) {
      if (newVal === 'Case') {
        this.searchForCase();
      }
    },
    title: function(newVal) {
      if (this.resource_type === 'Case') {
        this.searchForCase();
      }
    },
    lineInfo: function() {
      if (this.lineInfo.resource_type !== "Unknown") {
        this.resource_type = this.lineInfo.resource_type;
      }
    }
  },
  methods: {
    resetForm: function() {
      let resets = data();
      _.keys(resets).forEach((k) => {
        this[k] = resets[k];
      });
    },
    handleSubmit: function() {
      const data = {
        section: this.section,
        data: [{ title: this.title, resource_type: this.resource_type }]
      };
      this.postData(data);
      let k = {'Section':'sections', 'Case':'cases', 'Link':'links','Text':'texts','Temp':'temps'}[this.resource_type];
      this.stats[k] = _.get(this.stats,k,0) + 1;
    },
    postData: function(data) {
      this.$store.commit('globals/setAuditMode', false);
      const url = `/casebooks/${this.casebook}/new/bulk`;
      Axios.post(url, data).then(this.handleSuccess, this.handleFailure);
    },
    handleSuccess: function(resp) {
      this.$store.dispatch("table_of_contents/slowMerge", {
        casebook: this.casebook,
        newToc: resp.data
      });
      this.resetForm();
    },
    handleFailure: function(resp) {
      console.error(resp);
    },
    handlePaste: function(event) {
      let pasted = (event.clipboardData || window.clipboardData).getData(
        "text"
      );
      let parsed = pp.cleanDocLines(pasted);
      let [parsedJson, stats] = pp.structureOutline(parsed);
      _.keys(stats).map(k => {
        this.stats[k] = _.get(this.stats, k, 0) + stats[k];
      });
      this.postData({ data: parsedJson.children });
      this.title = "";
    },
    searchForCase: _.debounce(function searchForCase() {
      const query = pp.extractCaseSearch(this.title);
      this.$store.dispatch("case_search/fetch", { query });
    }, caseSearchDelay)
  }
};
</script>

<style lang="scss" scoped>
@import "../styles/vars-and-mixins";

#quick-add {
  border: 1px dashed black;
  padding: 4rem;
  .form {
    line-height: 36px;
    background-color: white;
    border: 1px solid black;
    padding: 8px;
  }

  .inline-search.form-control-group {
    display: flex;
    flex-direction: row;

    *:not(:first-child) {
      margin-left:1rem;
    }
    .resource-type {
      width:14rem;
    }
    .create-button {
      width: 12rem;
      font-size: 18px;
    }
  }
  .large-drop-down {
    line-height: 5rem;
    height: 46px;
    padding: 1rem 2rem;
    margin: 0rem;
    float: left;
    margin-right: 1.5rem;
  }
  .advice {
    margin-top:2rem;
    ul {
      margin-top:1rem;
    }
  }
  .stats {
    margin-top: 0.5rem;
    margin-left: 1rem;
  }
}
</style>

