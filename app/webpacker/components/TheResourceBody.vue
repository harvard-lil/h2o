<template>
<section class="resource" v-selectionchange="selectionChangeHandler">
  <TheGlobalElisionExpansionButton/>
  <TheAnnotator v-if="selection[0]"
                :selection="selection"/>
  <div class="case-text"
       v-for="(el, index) in sections">
    <ResourceSection :el="el"
                     :index="parseInt(index)"/>
  </div>
</section>
</template>

<script>
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
    selection: []
  }),
  computed: {
    sections() {
      const parser = new DOMParser();
      return parser.parseFromString(this.resource.content, "text/html").body.children;
    }
  },
  methods: {
    selectionChangeHandler(e, sel) {
      // if the selection is not zero width, store it, otherwise set to null 
      // this.selection is wrapped in an array in order to trigger rerender when changed
      this.$set(this.selection, 0, (sel && (sel.anchorNode != sel.focusNode ||
                                            sel.anchorOffset != sel.focusOffset)) ? sel : null);
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
  background-color: white;
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
.context-menu {
  position: absolute;
  right: 0;
}
</style>
