<template>
  <div v-bind:class="{'listing':true, 'resource':true, 'temporary': item.resource_type == 'Temp'}">
    <div class="section-number">{{rootOrdinalDisplay}}</div>
    <div class="resource-container resource-temporary" v-if="item.resource_type === 'Temp'">
      <a :href="url" class="section-title">{{ item.title }}</a>
    </div>
    <div class="resource-container" v-else-if="item.resource_type==='Case'">
      <a :href="url" class="section-title case-section-title">{{ item.title }}</a>
      <div class="case-metadata-container">
        <div class="resource-case">{{ item.citation }}</div>
        <div class="resource-date">{{ item.decision_date }}</div>
      </div>
    </div>

    <div class="resource-container" v-else>
      <a :href="url" class="section-title">{{ item.title }}</a>
    </div>

    <div class="resource-type-container">
      <div
        v-bind:class="{'resource-type': true, 'temporary': item.resource_type === 'Temp'}"
      >{{ item.resource_type === 'TextBlock' ? 'Text' : item.resource_type }}</div>
    </div>
  </div>
</template>

<script>
export default {
  props: ["item", "rootOrdinalDisplay", "editing"],
  computed: {
    url: function() {
      return this.editing ?  this.item.edit_url : this.item.url;
    }
  }
};
</script>

<style lang="scss" scoped>
.listing.resource.temporary {
  outline: 2px solid red;
}
</style>