<template>
<input id="link-input"
       type="url"
       required="true"
       pattern="\w+://\w+.*"
       placeholder="Url to link to..."
       ref="linkInput"
       :value="value"
       @input="$emit('input', $event.target.value)"/>
</template>

<script>
export default {
  props: ["value"]
}
</script>

<style lang="scss" scoped>
  #link-input {
    width: 200px;
  }
</style>
