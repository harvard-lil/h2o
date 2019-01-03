<template>
  <span>
    <div class="handle">
      <div class="number">
        {{index+1}}
      </div>
    </div>
    <span v-html="el.outerHTML"></span>
  </span>
</template>

<script>
export default {
  props: {
    el: {type: HTMLElement},
    index: {type: Number}
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
  
  &[data-elided-annotation]:not(.revealed){
    display: none;
  }
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
</style>
