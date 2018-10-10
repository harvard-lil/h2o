<template>
  <div id="app">
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
  }
}
</script>

<style scoped>
p {
  font-size: 2em;
  text-align: center;
}
</style>
