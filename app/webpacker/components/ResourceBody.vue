<template>
<section class="resource">
  <template v-for="section in sections">
    <ResourceSection v-html="section.outerHTML"></ResourceSection>
  </template>
</section>
</template>

<script>
import ResourceSection from "./ResourceSection";

export default {
  components: {
    ResourceSection
  },
  props: {
    resource: {type: Object},
    editable: {type: Boolean}
  },
  computed: {
    sections() {
      const parser = new DOMParser();
      return parser.parseFromString(this.resource.content, "text/html").body.children;
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
</style>
