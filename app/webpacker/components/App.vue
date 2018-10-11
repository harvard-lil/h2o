<template>
  <div v-selectionchange="selectionChangeHandler">
    <p>{{ message }}</p>
    <TheAnnotator/>
  </div>
</template>

<script>
import TheAnnotator from "./TheAnnotator.vue.erb";

export default {
  data: () => ({
    message: "Hello Vue!"
  }),
  components: {
    TheAnnotator
  },
  methods: {
    selectionChangeHandler: function(e, sel) {
      console.log(e, sel)
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
