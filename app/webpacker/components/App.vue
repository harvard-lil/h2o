<template>
  <div v-selectionchange="selectionChangeHandler">
    <p>{{ message }}</p>
    <TheAnnotator v-bind:mode="annotatorMode"/>
  </div>
</template>

<script>
import TheAnnotator from "./TheAnnotator.vue.erb";

export default {
  data: () => ({
    message: "Hello Vue!",
    annotatorMode: "inactive"
  }),
  components: {
    TheAnnotator
  },
  methods: {
    selectionChangeHandler: function(e, sel) {
      if(!sel || sel.isCollapsed){
        this.annotatorMode = "inactive";
      } else {
        this.annotatorMode = "create-menu";
      }
    }
  }
}
</script>

<style scoped>
p {
  font-size: 2em;
  text-align: center;
}
</style>
