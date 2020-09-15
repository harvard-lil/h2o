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
              <option :value="option.value" v-for="option in resource_type_options" v-bind:key="option.value">{{option.name}}</option>
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
      <div class="stats" v-if="waitingFor">
        <span>{{waitingFor}}</span>
        <loading-spinner></loading-spinner>
      </div>
    </div>
    <div class="advice">
      <span>Enter a single title or citation, or paste in a list or outline. To learn more, review our <a href="https://about.opencasebook.org/making-casebooks/#quick-add">quick add documentation.</a>  </span>
    </div>
  </div>
</template>

<script>
import _ from "lodash";
import LoadingSpinner from "./LoadingSpinner";
import Axios from "../config/axios";
import pp from "libs/text_outline_parser";
import urls from "libs/urls";

const optionsWithoutCloning = [{name: 'Section', value: 'Section'},
                               {name: 'Case', value: 'Case'},
                               {name: 'Text', value: 'TextBlock'},
                               {name: 'Link', value: 'Link'}];

const optionsWithCloning = optionsWithoutCloning.concat([{name: 'Clone', value: 'Clone'}]);

const data = function() {
  return {
    title: "",
    resource_type: "Section",
    resource_type_options: optionsWithoutCloning}
};
const caseSearchDelay = 1000;

export default {
  components: {
    LoadingSpinner // eslint-disable-line vue/no-unused-components
  },
  props: ["casebook", "section", "rootOrdinals"],
  data: function() {
    return { ...data(), stats: {}, waitingFor: false, unWait: () => {} };
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
      if (newVal === "Case") {
        this.searchForCase();
      }
    },
    title: function(newVal) {
      if (this.resource_type === "Case") {
        this.searchForCase();
      }
    },
    lineInfo: function() {
      if (this.lineInfo.resource_type !== "Unknown") {
        this.resource_type = this.lineInfo.resource_type;
        if (this.resource_type !== 'Clone') {
          this.resource_type_options = optionsWithoutCloning;
        } else {
          this.resource_type_options = optionsWithCloning;      
        }
      }
    }
  },
  methods: {
    bulkAddUrl: urls.url('new_from_outline'),
    resetForm: function() {
      let resets = data();
      _.keys(resets).forEach(k => {
        this[k] = resets[k];
      });
      this.waitingFor = false;
      this.unWait();
      this.unWait = () => {};
    },
    lowHangingCaseCheck: function(data) {
      let query = _.get(data, 'data.0.searchString') || _.get(data, 'data.0.title');
      
      if (query) {
        this.$store.dispatch("case_search/fetch", { query });
      }
    },
    handleSubmit: function() {
      const data = {
        section: this.section,
        data: [{...this.lineInfo, title:this.title}]
      };
      if (data.data[0].resource_type === 'Unknown') { data.data[0].resource_type = 'Temp';}
      if (data.data[0].resource_type === 'Link') {
        if (!data.data[0].url) {
          data.data[0].url = data.data[0].title;
        }
        data.data[0].title = undefined;
      }
      data.data[0].resource_type = this.resource_type;
      if (this.resource_type === 'Case' && !_.has(data,'data.0.resource_id')) {
        this.lowHangingCaseCheck(data);
      }
      this.postData(data);
      let k = {
        Section: "sections",
        Case: "cases",
        Link: "links",
        Text: "texts",
        Temp: "temps"
      }[this.resource_type];
      this.stats[k] = _.get(this.stats, k, 0) + 1;
    },
    postData: function(data) {
      return Axios.post(this.bulkAddUrl({casebookId:this.casebook}), data).then(this.handleSuccess, this.handleFailure);
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
      if ( pasted.indexOf("\n") >= 0) {
        this.waitingFor = "Parsing pasted text";
        let parsed = pp.cleanDocLines(pasted);
        let [parsedJson, stats] = pp.structureOutline(parsed);
        _.keys(stats).map(k => {
          this.stats[k] = _.get(this.stats, k, 0) + stats[k];
        });
        this.postData({ section: this.section,
                        data: parsedJson.children });
        this.title = "";
      } else {
        this.title += pasted;
      }
    },
    searchForCase: _.debounce(function searchForCase() {
      const query = pp.extractCaseSearch(this.title);
      if (query) {
        this.$store.dispatch("case_search/fetch", { query });
      }
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
            margin-left: 1rem;
        }
        .resource-type {
            width: 14rem;
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
        margin-top: 2rem;
    ul {
      margin-top: 1rem;
    }
  }
  .stats {
    margin-top: 0.5rem;
    margin-left: 1rem;
  }
}
</style>

