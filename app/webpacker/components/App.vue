<template>
<TheAnnotator v-bind:mode="annotatorMode" v-bind:range="annotatorRange"/>
</template>

<script>
import TheAnnotator from "./TheAnnotator.vue.erb";

export default {
  data: () => ({
    annotatorMode: "inactive",
    annotatorRange: null
  }),
  components: {
    TheAnnotator
  },
  methods: {
    selectionChangeHandler(e, sel) {
      if(!sel || sel.isCollapsed){
        this.annotatorMode = "inactive";
      } else {
        this.annotatorMode = "create-menu";
        this.annotatorRange = sel.getRangeAt(0);
      }
    }
  }
}
</script>

<style scoped>
</style>
