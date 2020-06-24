<template>
  <div class="new-text">
    <div id="outliner" v-if="step== 'outline'">
      <editor
        ref="outliner"
        :init="tinyMCEInitConfig"
        :inline="false"
        v-model="savedContents"
        output-format="html"
        @onFocus="clearInitial"
        @onBlur="resetPlaceholder"
      />
    </div>
    <div v-else>
      <case-selector v-model="caseDisambiguation" @done="saveOutline" />
    </div>
    <div class="form-group">
      <form v-if="step === 'outline'">
        <input
          v-if="totalCaseCount > 0"
          v-on:click.prevent.stop="caseStep"
          class="search-button"
          type="submit"
          :value="selectButtonText"
        />
        <input
          v-else
          v-on:click.prevent.stop="saveCaseFreeOutline"
          class="search-button"
          type="submit"
          value="Save Outline"
        />
      </form>
    </div>
  </div>
</template>

<script>
import _ from "lodash";
import Editor from "@tinymce/tinymce-vue";
import LoadingSpinner from "./LoadingSpinner";
import CaseSelector from "./CaseSelector";
import Axios from "../config/axios";
//import TheTableOfContents from "../components/TheTableOfContents";
import pp from "libs/text_outline_parser";
import tinymce from "tinymce/tinymce"; // eslint-disable-line no-unused-vars
import "tinymce/themes/silver";
import "tinymce/plugins/link";
import "tinymce/plugins/lists";
import "tinymce/plugins/image";
import "tinymce/plugins/table";
import "tinymce/plugins/code";
import "tinymce/plugins/paste";

const bagName = "casebookOutlinerContents";
const placeholder =
  "<ol><li>Paste your table of contents/syllabus/reading list here</li></ol>";

export default {
  components: {
    editor: Editor,
    LoadingSpinner, // eslint-disable-line vue/no-unused-components
    CaseSelector
  },
  data: function() {
    return {
      outlineStructure: {},
      step: "outline",
      showing: "Edit",
      tinyMCEInitConfig: {
        plugins: "lists paste",
        skin_url: "/static/tinymce_skin",
        menubar: false,
        branding: false,
        toolbar: "undo redo | indent outdent | casebutton headnoteButton",
        style_formats: [
          { title: "Case", inline: "strong" },
          { title: "Headnote", inline: "em" }
        ],
        valid_elements: "ol,li,span,strong,em",
        invalid_elements: "p,div",
        placeholder: "Paste your table of contents or syllabus here.",
        paste_preprocess: this.handlePrePaste,
        paste_word_valid_elements: "ol,li,span,strong,em",
        paste_enable_default_filters: false,
        paste_as_text: true,
        setup: this.tinymceSetup,
        fix_list_elements: true
      }
    };
  },
  directives: {},
  computed: {
    smartContents: function() {
      // There are a pair of races that this tries to get around, with pasting, and mounting the component
      const tinyMCEDefault = "<p><br data-mce-bogus=\"1\"></p>";
      let tempContents = this.$refs.outliner.editor.contentDocument.children[0]
        .children[1].innerHTML;
      if (tempContents === tinyMCEDefault) {
        return this.savedContents;
      }
      return tempContents;
    },
    savedContents: {
      get: function() {
        return _.get(this.$store.state.shared_bag, bagName, placeholder);
      },
      set: function(value) {
        this.$store.commit("shared_bag/overwrite", { bagName, value });
      }
    },
    caseDisambiguation: {
      get: function() {
        return _.get(this.$store.state.shared_bag, 'casebookOutlinerCaseDisambiguation', []);
      },
      set: function(value) {
        this.$store.commit("shared_bag/overwrite", { bagName:'casebookOutlinerCaseDisambiguation', value });
      }
    },
    selectButtonText: function() {
      return `Select Cases ${this.identifiedCaseCount}/${this.totalCaseCount}`;
    },
    identifiedCaseCount: function() {
      return _.map(this.caseDisambiguation).filter(c => c[1] !== null).length;
    },
    totalCaseCount: function() {
      return this.caseDisambiguation.length;
    }
  },
  methods: {
    tinymceSetup: function(editor) {
      editor.ui.registry.addButton("caseButton", {
        text: "Case",
        onAction: function(_) {
          editor.execCommand("Bold", true, null);
        }
      });
      editor.ui.registry.addButton("headnoteButton", {
        text: "Headnote",
        onAction: function(_) {
          editor.execCommand("Italic", true, null);
        }
      });

      // JavaScript
      let self = this;
      editor.on("init", function() {
        editor.execCommand("InsertOrderedList");
      });
      editor.on("NodeChange", ({ element }) => {
        if (
          element.nodeName === "P" &&
          element.parentElement.id === "tinymce"
        ) {
          editor.execCommand("InsertOrderedList");
        }
      });
      editor.on("ExecCommand", ({ command, value }) => {
        if (
          command === "Bold" ||
          (command === "mceToggleFormat" && value === "bold")
        ) {
          self.$nextTick(self.parseContentsAndSearch);
        }
      });
    },
    saveCaseFreeOutline: function() {
      this.parseContentsAndSearch();
      this.saveOutline();
    },
    saveOutline: function() {
      const url = `/casebooks/${this.casebook}/new/bulk`;
      const caseMapping = {};
      this.caseDisambiguation.forEach(
        row => (caseMapping[row[0].title] = row[1])
      );

      function augmentCases(node) {
        let { title, headnote, resource_type, children } = node;
        let cap_id;
        if (resource_type === "Case") {
          let id = caseMapping[title];
          if (id === "TextBlock") {
            resource_type = "TextBlock";
          } else {
            cap_id = id;
          }
        } else if (resource_type === "Section") {
          children = children.map(augmentCases);
        }
        return { title, headnote, resource_type, cap_id, children };
      }
      let data = _.cloneDeep(this.outlineStructure).map(augmentCases);
      const payload = { section: this.section, data };
      Axios.post(url, payload).then(this.handleSubmitResponse, console.error);
    },
    handleSubmitResponse: function handleSubmitResponse(response) {
      let location = response.request.responseURL;
      window.location.href = location;
      this.errors = {};
    },
    parseContentsAndSearch: function() {
      let domparser = new DOMParser();
      let tempContents = this.smartContents;
      let nodes = domparser.parseFromString(tempContents, "text/html");
      let topList = nodes.children[0].children[1].children[0];
      let [outline, case_queries] = pp.parseList(topList);
      this.outlineStructure = outline;
      this.setCaseLoad(case_queries);
    },
    setCaseLoad: function(cases) {
      cases.map(x => this.searchForCase(x.case_query));
      this.caseDisambiguation = cases.map(q => [q, null]);
    },
    caseStep: function() {
      this.parseContentsAndSearch();
      this.step = "cases";
    },
    outlineStep: function() {
      this.step = "outline";
    },
    resetPlaceholder: function() {
      if (this.savedContents == "") {
        this.savedContents = placeholder;
      }
    },
    clearInitial: function() {
      if (this.contents == placeholder) {
        this.contents = "<ol><li></li></ol>";
      }
    },
    handlePrePaste: function handlePrePaste(plugin, args) {
      let text = args.content
        .replace(/&lt;p&gt;|<p>/g, "")
        .replace(/&lt;\/p&gt;|<\/p>/g, "\n")
        .replace(/$lt;br *\/&gt;/g, "\n")
        .replace(/<br *\/>/g, "\n");
      let parsed = pp.parsePaste(text);
      let [nestedList, _cases] = pp.toNestedList(parsed);
      this.$nextTick(this.parseContentsAndSearch);
      args.content = nestedList;
    },
    searchForCase: function searchForCase(query) {
      this.$store.dispatch("case_search/fetch", { query });
    }
  },
  props: ["casebook", "rootId"],
  watch: {
    savedContents: function() {
      this.parseContentsAndSearch();
    }
  },
  mounted: function() {
    this.savedContents = this.savedContents.replace(/\n/g, "");
    const w = this.savedContents;
    const self = this;
    function whenceContentful() {
      console.log("whence");
      if (self.savedContents == w) {
        self.parseContentsAndSearch();
      } else {
        self.$nextTick(whenceContentful);
      }
    }
    whenceContentful();
  }
};
</script>

<style lang="scss">
@import "../styles/vars-and-mixins";

#outliner {
  .mce-content-body {
    height: 100%;
  }

  border: 2px solid grey;
  border-radius: 8px;
  margin: 20px 40px;
  padding: 8px;
  overflow-y: scroll;
  max-height: 460px;
  ol {
    counter-reset: item;
    list-style: lower-latin;
  }
  li {
    counter-increment: item;
    display: block;
    &:before {
      content: counters(item, ".") " ";
    }
  }
  span[data-type="unknown"] {
    background-color: rgba(255, 0, 0, 0.4);
  }
  span[data-type="section"] {
    background-color: rgba(0, 255, 0, 0.4);
  }
  span[data-type="case"] {
    background-color: rgba(0, 0, 255, 0.4);
  }
  span[data-type="text"] {
    background-color: rgba(255, 166, 0, 0.4);
  }
}
.red {
  background-color: red;
}
</style>
