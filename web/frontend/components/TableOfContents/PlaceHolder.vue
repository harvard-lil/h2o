<template>
  <div v-if="editing">
    <div class="listing empty">
      <div class="add-content-link">
        This {{nodeType}} is empty.
      </div>
    </div>
  </div>
</template>

<script>
export default {
    props: ["editing", "nodeType"]
}
</script>
