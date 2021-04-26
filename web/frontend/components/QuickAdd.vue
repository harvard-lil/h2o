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
            <select v-model="resource_info" class="resource-type form-control">
              <option :value="option.value" v-for="option in resource_info_options" v-bind:key="option.k">{{option.name}}</option>
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
import { createNamespacedHelpers } from "vuex";

const globals = createNamespacedHelpers("globals");
const search = createNamespacedHelpers("case_search");

const optionsWithoutCloning = [{name: 'Section', value: {resource_type: 'Section'}, k: 0},
                               {name: 'Search',  value: {resource_type: 'Case'}, k: 1},
                               {name: 'Text',    value: {resource_type: 'TextBlock'}, k: 2},
                               {name: 'Link',    value: {resource_type: 'Link'}, k: 3}];

const data = function() {
  return {
    title: "",
    resource_info: optionsWithoutCloning[0].value,
    resource_info_options: optionsWithoutCloning}
};
const caseSearchDelay = 1000;

export default {
  components: {
    LoadingSpinner // eslint-disable-line vue/no-unused-components
  },
  props: [],
  data: function() {
    return { ...data(), stats: {}, waitingFor: false, unWait: () => {} };
  },
  directives: {},
  computed: {
    ...globals.mapGetters(['casebook', 'section']),
    ...search.mapGetters(['getSources']),
    totalIdentified: function() {
      return _.values(this.stats).reduce((a, b) => a + b, 0);
    },
    lineInfo: function() {
      return pp.guessLineType(this.title, this.getSources);
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
    lineInfo: function() {
      if (this.lineInfo.resource_type !== "Unknown") {
        if (this.lineInfo.resource_type === 'Temp') {
          let k = 5;
          let newOptions = _.chain(this.lineInfo.guesses)
              .map(guess => ({name: guess.display_type, value: guess}))
              .uniqBy(x => x.name)
              .map(option => ({...option, k:k++}))
              .value();
          this.resource_info_options = _.concat(newOptions, optionsWithoutCloning);
          this.resource_info = this.lineInfo.guesses[0];
        } else if (this.lineInfo.resource_type === 'Clone') {
          let options = _.concat([{name: this.lineInfo.display_type, value: this.lineInfo, k:5}],_.cloneDeep(optionsWithoutCloning));
          this.resource_info = options[0].value;
          this.resource_info_options = options;
        } else {
          let options = _.concat([{name: this.lineInfo.display_type, value: this.lineInfo.resource_type, k:5}],_.cloneDeep(optionsWithoutCloning));
          this.resource_info = options[0].value;
          this.resource_info_options = options;
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
      this.manualResourceType = false;
    },
    handleSubmit: function() {
      let desiredSubset = _.pick(this.resource_info, ['resource_type', 'url', 'casebookId', 'resource_id', 'sectionId', 'sectionOrd', 'userSlug','titleSlug', 'ordSlug'])
      let nodeData = {...desiredSubset, title:this.title}

      if (nodeData.resource_type === 'Unknown') {
        nodeData.resource_type = 'Temp';
      }
      if (nodeData.resource_type === 'Link') {
        if (!nodeData.url) {
          nodeData.url = nodeData.title;
        }
        nodeData.title = undefined;
      }
      const data = {
        section: this.section(),
        data: [nodeData]
      };
      this.postData(data);
    },
    postData: function(data) {
      return Axios.post(this.bulkAddUrl({casebookId:this.casebook()}), data).then(this.handleSuccess, this.handleFailure);
    },
    handleSuccess: function(resp) {
      this.$store.dispatch("table_of_contents/slowMerge", {
        casebook: this.casebook(),
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
        let [parsedJson, stats] = pp.structureOutline(parsed, this.getSources);
        _.keys(stats).map(k => {
          this.stats[k] = _.get(this.stats, k, 0) + stats[k];
        });
        this.postData({ section: this.section(),
                        data: parsedJson.children });
        this.title = "";
      } else {
        this.title += pasted;
      }
    },
    searchForCase: _.debounce(function searchForCase() {
      let query = this.title;
      if (query) {
        this.$store.dispatch("case_search/fetchForAllSources", { query });
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

