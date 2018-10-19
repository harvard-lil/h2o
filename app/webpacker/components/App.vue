<template>
<div>
<TheAnnotator v-bind:mode="annotatorMode" v-bind:range="annotatorRange"/>
<TheResource/>
</div>
</template>

<script>
import TheResource from "./TheResource";
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
    selectionChangeHandler(e) {
      const sel = document.getSelection();
      if(!sel || sel.isCollapsed){
        this.annotatorMode = "inactive";
      } else {
        this.annotatorRange = sel.getRangeAt(0);
        this.annotatorMode = "create-menu";
      }
    }
  },
  created() {
    document.addEventListener('selectionchange', this.selectionChangeHandler);
  },
  destroyed() {
    document.removeEventListener('selectionchange', this.selectionChangeHandler);
  }
}
</script>

<style scoped>
</style>
