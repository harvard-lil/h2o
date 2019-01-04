<template>
<component :is="el.tagName"
           :class="el.getAttribute('class')"
           :style="el.getAttribute('style')"
           :href="el.getAttribute('href')"
           :alt="el.getAttribute('alt')"
           :src="el.getAttribute('src')">
  <template v-for="node in el.childNodes">
    <template v-if="node.nodeType == node_types.TEXT">{{node.textContent}}</template>
    <resource-element v-else-if="node.nodeType == node_types.ELEMENT"
                      :el="node"
                      :index="index"/>
  </template>
</component>
</template>

<script>
export default {
  name: "resource-element", // required for recursive use
  props: {
    el: {type: HTMLElement},
    index: {type: Number},
    offset: {type: Number,
             default: 0}
  },
  data: () => ({
    node_types: {ELEMENT: 1,
                 TEXT: 3}
  }),
  computed: {
    annotations() {
      return this.$store.getters['annotations/getBySectionIndex'](this.index);
    }
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';
</style>
