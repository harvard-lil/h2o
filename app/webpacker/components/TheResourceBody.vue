<template>
<section class="resource"
         v-selectionchange="selectionChangeHandler">
  <TheAnnotator ref="annotator"
                v-if="ranges"
                :ranges="ranges"/>
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
    selectionChangeHandler(e, sel) {
      this.ranges =
        (!sel || sel.type != "Range")
        ? null
        : {first: sel.getRangeAt(0),
           last: sel.getRangeAt(sel.rangeCount-1)};
    }
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
