<template>
<component :is="el.tagName"
           :id="el.getAttribute('id')"
           :class="el.getAttribute('class')"
           :style="el.getAttribute('style')"
           :href="el.getAttribute('href')"
           :alt="el.getAttribute('alt')"
           :src="el.getAttribute('src')">
  <template v-for="obj in childNodesWithOffsets">
    <b style="color: red;">{{obj.offset}}</b>
    <template v-if="obj.node.nodeType == node_types.TEXT">{{obj.node.textContent}}</template>
    <resource-element v-else-if="obj.node.nodeType == node_types.ELEMENT"
                      :el="obj.node"
                      :index="index"
                      :offsetToPoint="obj.offset"/>
  </template>
</component>
</template>

<script>
export default {
  name: "resource-element", // required for recursive use
  props: {
    el: {type: HTMLElement},
    index: {type: Number},
    offsetToPoint: {type: Number,
                    default: 0}
  },
  data: function(){
    return {
      node_types: {ELEMENT: 1,
                   TEXT: 3},
      offset: this.offsetToPoint
  }},
  computed: {
    annotations() {
      return this.$store.getters['annotations/getBySectionIndex'](this.index);
    },
    childNodesWithOffsets() {
      return Array.from(this.el.childNodes).map(node => {
        let prev_offset = this.offset;
        // uses innerText for element nodes and falls through to
        // textContent for text nodes
        this.offset = this.offset + (node.innerText || node.textContent).length;
        return {node: node, offset: prev_offset};
      })
    }
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';
</style>
