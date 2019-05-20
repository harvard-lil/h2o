<template>
<button @click="toggleAllExpansions">
  <template v-if="areAllExpanded">Hide</template>
  <template v-else>Show</template>
  elided text
</button>
</template>

<script>
import { createNamespacedHelpers } from 'vuex';
const { mapGetters,
        mapActions } = createNamespacedHelpers('annotations_ui');

export default {
  computed: {
    ...mapGetters(['areAllExpanded'])
  },
  methods: {
    ...mapActions(['toggleAllExpansions'])
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';
@import "~bootstrap-sass/assets/stylesheets/bootstrap/buttons";

button {
  @extend .btn;
  @include button-variant($light-blue, white, $light-blue);
  @include set-font($font-family-sans-serif, 700, 14px, normal);
  border-radius: 5px;
  border: solid 1.5px;
  line-height: 23px;
  margin-bottom: 20px;
  &:hover {
    @include generic-focus-styles;
  }
}
</style>
