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
import ContextMenu from "./ContextMenu";
import { Y_FIDELITY } from "../store/modules/annotations_ui.js";
import _ from "lodash";

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
      const onSameLine =
            this.$store.getters['annotations_ui/getByHeadY'](this.uiState.headY)
            // remove annotations that haven't been saved yet
            .filter(a => a.id)
            // order by offset
            .sort((a, b) => a.start_offset - b.start_offset);
      return -55 - (30 * (Math.max(0, onSameLine.indexOf(this.uiState))));
    }
  },
  methods: {
    updateHeadY: _.debounce(function() {
      const newHeadY = this.$el.getBoundingClientRect().top + window.scrollY;
      // Only update the headY if it's shifted by more than a certain
      // number of pixels. Small changes to the DOM can shift it by a
      // pixel or two, causing excessive updates and performance issues.
      // We avoid those by rounding to a certain degree.
      if (Math.abs(newHeadY - this.uiState.headY) > Y_FIDELITY) {
        this.$store.commit(
          'annotations_ui/update',
          {obj: this.uiState,
           vals: {headY: newHeadY}});
      }
    }, 100)
  },
  mounted() {
    this.updateHeadY();
  },
  updated() {
    this.updateHeadY();
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';

$size: 28px;

.annotation-handle {
  font-size: 1.65rem;
  font-style: normal;
  clear: both;
  float: right;
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
  font-family: "Chronicle Text G3", Georgia, "Times New Roman", Times, serif;
}
</style>
