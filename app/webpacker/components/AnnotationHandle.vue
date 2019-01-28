<template>
<span class="annotation-handle"
      data-exclude-from-offset-calcs="true">
  <button ref="button"
          aria-label="Edit annotation"
          class="annotation-button"
          :style="{right: offsetRight + 'px'}"
          @click.prevent="$refs.menu.open">✎</button>
  <ContextMenu ref="menu">
    <ul><slot></slot></ul>
  </ContextMenu>
</span>
</template>

<script>
import ContextMenu from './ContextMenu';

export default {
  components: {
    ContextMenu
  },
  props: {
    uiState: {type: Object,
              required: true}
  },
  computed: {
    offsetRight() {
      let onSameLine =
          this.$store.getters['annotations_ui/getByHeadY'](this.uiState.headY)
          // remove annotations that haven't been saved yet
          .filter(a => a.id)
          // order by offset
          .sort((a, b) => a.start_offset - b.start_offset);
      return -15 - (30 * (Math.max(0, onSameLine.indexOf(this.uiState))));
    }
  },
  mounted() {
    this.$store.commit(
      'annotations_ui/update',
      {obj: this.uiState,
       vals: {headY: this.$el.getBoundingClientRect().top + window.scrollY}}
    );
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';

$size: 28px;

.annotation-handle {
  font-size: 1.65rem;
  font-style: normal;
}

.annotation-button {
  @include square($size);
  position: absolute;
  right: 0;
  padding: 0;
  user-select: none;
  text-align: center;
  line-height: $size;
  border-radius: $size;
  color: $light-blue;
  border: 2px solid $white;
  background: $light-gray;
}
</style>
