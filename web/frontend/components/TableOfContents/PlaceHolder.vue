<template>
  <div v-if="editing">
    <div class="listing empty">
      <div class="add-content-link">
        This casebook is empty.
      </div>
    </div>
  </div>
</template>

<script>
export default {
    props: ["editing"]
}
</script>