<template>
<section class="resource"
         v-selectionchange="selectionchangeHandler">
  <TheAnnotator v-if="editable"
                ref="annotator"/>
  <TheGlobalElisionExpansionButton/>
  <div class="case-text">
    <template v-for="(el, index) in sections">
      <ResourceSection :el="el"
                       :index="parseInt(index)"/>
    </template>
  </div>
</section>
</template>

<script>
import { createNamespacedHelpers } from "vuex";
const { mapActions } = createNamespacedHelpers("annotations");

import ResourceSection from "./ResourceSection.js";
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
    sections() {
      const parser = new DOMParser();
      return parser.parseFromString(this.resource.content, "text/html").body.children;
    }
  },
  methods: {
    ...mapActions(["list"]),

    // The selectionchange directive must be bound to the broader
    // <section.resource> (rather than TheAnnotator) so that it has
    // context about which text with which to be concerned.
    // The TheAnnotator handler is then proxied through rather than
    // set directly on the directive because $refs doesn't exist at
    // the point it's added
    selectionchangeHandler(e, sel) {
      this.$refs.annotator && this.$refs.annotator.selectionchange(e, sel);
    }
  },
  created() {
    this.$store.commit("resources_ui/setEditability", this.editable);
    this.list({resource_id: document.querySelector("header.casebook").dataset.resourceId});
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';

.resource {
  position: relative;
  @include serif-text($regular, 18px, 31px);
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
  /* hacks for misbehaving blockquotes */
  blockquote {
    span p {
      display: inline; // yes, p in span is illegal, but we have them
    }
    &[data-elided-annotation]:not(.revealed){
      margin: 0;
      padding: 0;
    }
  }
}
</style>
