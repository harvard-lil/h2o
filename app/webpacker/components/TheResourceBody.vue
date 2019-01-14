<template>
<section class="resource"
         v-selectionchange="selectionchangeHandler">
  <TheAnnotator v-if="editable"
                ref="annotator"/>
  <TheGlobalElisionExpansionButton/>
  <div class="case-text">
    <template v-for="(el, index) in sections">
      <div class="handle">
        <div class="number">
          {{parseInt(index)+1}}
        </div>
      </div>
      <ResourceElement :el="el"
                       :index="parseInt(index)"
                       :data-index="index"
                       class="section"/>
    </template>
  </div>
</section>
</template>

<script>
import { createNamespacedHelpers } from "vuex";
const { mapActions } = createNamespacedHelpers("annotations");

import ResourceElement from "./ResourceElement";
import TheAnnotator from "./TheAnnotator";
import TheGlobalElisionExpansionButton from "./TheGlobalElisionExpansionButton";

export default {
  components: {
    ResourceElement,
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
      return this.$refs.annotator.selectionchange(e, sel);
    }
  },
  created() {
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
.handle {
  @include size(0px, 0px);

  user-select: none;

  float: left;
  position: relative;

  &[data-elided-annotation]:not(.revealed){
    display: none;
  }
}
.number {
  @include sans-serif($regular, 12px, 12px);

  position: absolute;
  right: 45px;
  line-height: 34px;

  color: $light-blue;
  text-align: right;
  vertical-align: middle;
}
.section {
  position: relative;
}

/*
 * This counteracts a normalize.css style
 * that messes up annotation handle positioning
 */
/deep/ {
  sub, sup {
    position: static;
    line-height: 100%;
  }
  sup {vertical-align: super; }
  sub { vertical-align: sub; }
}

/*
 * These use /deep/ to influence HighlightAnnotation.
 * They must live here so that they can change in relation to
 * their parent element.
 */
p /deep/ .highlight .selected-text {
  padding: 0.4em 0;
}
h2 /deep/ .highlight .selected-text {
  padding: 0.05em 0;
}
</style>
