<template>
<section class="resource" v-selectionchange="selectionChangeHandler">
  <TheGlobalElisionExpansionButton/>
  <ContextMenu ref="menu">
    <ul><li>hey</li></ul>
  </ContextMenu>
  <div class="resource-wrapper">
    <div class="case-text"
         v-for="(el, index) in sections">
      <ResourceSection :el="el"
                       :index="parseInt(index)"/>
    </div>
  </div>
</section>
</template>

<script>
import ResourceSection from "./ResourceSection";
import TheAnnotator from "./TheAnnotator.vue.erb";
import TheGlobalElisionExpansionButton from "./TheGlobalElisionExpansionButton";
import ContextMenu from './ContextMenu';

export default {
  components: {
    ResourceSection,
    TheAnnotator,
    TheGlobalElisionExpansionButton,
    ContextMenu
  },
  props: {
    resource: {type: Object},
    editable: {type: Boolean}
  },
  data: () => ({
    selection: null
  }),
  computed: {
    sections() {
      const parser = new DOMParser();
      return parser.parseFromString(this.resource.content, "text/html").body.children;
    },
    offset() {
      let wrapperRect = document.querySelector('.resource-wrapper').getBoundingClientRect();
      let viewportTop = window.scrollY - (wrapperRect.top + window.scrollY);
      
      let target = this.range || this.handle;
      this.targetRect = target ? target.getBoundingClientRect() : this.targetRect || {top: 0, bottom: 0};
      
      return Math.min(Math.max(this.targetRect.top - wrapperRect.top,
                               viewportTop + 20),
                      this.targetRect.bottom - wrapperRect.top).toString(10) + "px";
    }
  },
  methods: {
    selectionChangeHandler(e, sel) {
      console.log(e);
      if(sel) {
        this.$refs.menu.open({});
      } else {
        this.$refs.menu.close(e);
      }
    }
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';

.resource {
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
.resource-wrapper {
  position: relative;
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
