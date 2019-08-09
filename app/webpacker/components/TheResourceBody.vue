<template>
<section class="resource"
         v-selectionchange="selectionchangeHandler">
  <TheAnnotator v-if="editable"
                ref="annotator"/>
  <TheGlobalElisionExpansionButton v-if="collapsible.length"/>
  <div class="case-text">
    <template v-for="(el, index) in sections">
      <ResourceSection :el="el"
                       :index="parseInt(index)"/>
    </template>
  </div>
</section>
</template>

<script>
import { unwrapUndesiredTags,
         emptyULToP,
         wrapBareInlineTags,
         removeEmptyNodes } from "../libs/html_helpers.js";

import { createNamespacedHelpers } from "vuex";
const { mapActions } = createNamespacedHelpers("annotations");
const { mapGetters } = createNamespacedHelpers("annotations_ui");

import ResourceSection from "./ResourceSection";
import TheAnnotator from "./TheAnnotator";
import TheGlobalElisionExpansionButton from "./TheGlobalElisionExpansionButton";

export default {
  components: {
    ResourceSection,
    TheAnnotator,
    TheGlobalElisionExpansionButton
  },
  props: {
    resource: {type: Object},
    editable: {type: Boolean}
  },
  data: () => ({
    ranges: null
  }),
  computed: {
    ...mapGetters(["collapsible"]),

    sections() {
      const parser = new DOMParser();
      let doc = parser.parseFromString(this.resource.content, "text/html");

      // Some resources are pure text without a wrapping HTML doc.
      // In this case, body.children will return an empty array.
      // Wrap that text in a div so that ResourceSection can expect HTMLElements
      if(doc.body.children.length == 0) {
        let div = document.createElement("div");
        div.appendChild(document.createTextNode(this.resource.content));
        return [div];
      } else {
        unwrapUndesiredTags(doc);
        emptyULToP(doc);
        wrapBareInlineTags(doc);
        removeEmptyNodes(doc);
        return doc.body.children;
      }
    },

    resourceId() {
      const header = document.querySelector("header.casebook");
      return header ? header.dataset.resourceId : null;
    }
  },
  methods: {
    ...mapActions(["list"]),

    // The selectionchange directive must be bound to the broader
    // <section.resource> (rather than TheAnnotator) so that it has
    // context about.html which text with which to be concerned.
    // The TheAnnotator handler is then proxied through rather than
    // set directly on the directive because $refs doesn't exist at
    // the point it's added
    selectionchangeHandler(e, sel) {
      this.$refs.annotator && this.$refs.annotator.selectionchange(e, sel);
    }
  },
  created() {
    this.$store.commit("resources_ui/setEditability", this.editable);
    if(this.resourceId) this.list({resource_id: this.resourceId});
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';

.resource {
  position: relative;
  margin-bottom: 24px;
  padding: 40px;
  background-color: $white;
  h5 {
    font-size: 14px;
    margin: 30px 0px 15px 0px;
  }
  h3 {
    @include serif-text($medium, 24px, 27px);
    margin: 10px 0;
    color: $orange;
  }
  @media (max-width: $screen-xs) {
    h2 {
      @include serif-text($bold, 19px, 34px);
    }
  }
  p {
    @include serif-text($regular, 19px, 34px);
  }
  strong {
    @include sans-serif($bold, 18px, 40px);
  }
  .resource-center {
    text-align: center;
  }
}
.case-text {
  @include serif-text($regular, 18px, 31px);
  /* hacks for misbehaving blockquotes */
  blockquote {
    span p {
      display: inline; // yes, p in span is illegal, but we have them
    }
  }
}
</style>
