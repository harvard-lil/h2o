<template>
<input id="link-input"
       placeholder="Url to link to..."
       :value="value"
       @input="$emit('input', $event.target.value)"/>
</template>

<script>
export default {
  props: ["value"]
}
</script>

<style lang="scss" scoped>
</style>
