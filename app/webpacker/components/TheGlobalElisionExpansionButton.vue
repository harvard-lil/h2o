<template>
<button @click="handleClick">
  <template v-if="expanded">Show</template>
  <template v-else>Hide</template>
  elided text
</button>
</template>

<script>
import { createNamespacedHelpers } from 'vuex';
const { mapMutations } = createNamespacedHelpers('annotations_ui');

export default {
  data: () => ({
    expanded: false
  }),
  methods: {
    ...mapMutations(['toggleAllExpansions']),
    handleClick() {
      this.expanded = !this.expanded;
      this.toggleAllExpansions(this.expanded);
    }
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
