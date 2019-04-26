<template>
<div class="section">
  <div v-if="expanded"
       class="handle">
    <div class="number">
      {{index+1}}
    </div>
  </div>
  <div :data-index="index"><slot></slot></div>
</div>
</template>

<script>
export default {
  props: {
    tuple: {type: Array,
            required: true},
    index: {type: Number,
           required: true}
  },
  computed: {
    expanded() {
      // If any annotation that spans the entire section is hidden, return false
      return this.$store.getters['annotations/getSpanningOffsets'](this.index, this.tuple[1], this.tuple[2])
        .filter(annotation => annotation.kind != "note")
        .reduce((expanded, annotation) => {
          const ui_state = this.$store.getters['annotations_ui/getById'](annotation.id);
          return expanded && (!ui_state || ui_state.expanded);
        }, true);
    },
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';

.handle {
  @include size(0px, 0px);

  user-select: none;

  float: left;
  position: relative;
}
.number {
  @include sans-serif($regular, 12px, 12px);

  position: absolute;
  right: 45px;
  line-height: 34px;

  color: $light-blue;
  text-align: right;
  vertical-align: middle;
}
.page-number {
  font-size: small;
  color: darkgrey;
  vertical-align: super;
  margin: 4px;
}
/*
 * These use /deep/ to influence HighlightAnnotation.
 * They must live here so that they can change in relation to
 * their parent element.
 */
p /deep/ {
  .highlight .selected-text,
  .replacement .selected-text,
  .replacement .replacement-text {
    padding: 0.35em 0;
  }
}
h2 /deep/ {
  .highlight .selected-text,
  .replacement .selected-text,
  .replacement .replacement-text {
    padding: 0.05em 0;
  }
}
</style>
