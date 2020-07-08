<template>
  <div class="listing section">
    <button
      aria-role="heading"
      :aria-expanded="!collapsed ? 'true' : 'false'"
      :aria-label="collapsed ? 'expand ' + item.title : 'collapse ' + item.title"
      v-on:click="toggleSectionExpanded"
      class="action-expand"
      v-if="item.children.length > 0 || collapsed"
    >
      <collapse-triangle :collapsed="collapsed" />
    </button>
    <div class="no-collapse-padded" v-else></div>
    <div class="section-number">{{rootOrdinalDisplay}}</div>
    <div class="section-title">
      <a :href="url" class="section-title">{{ item.title }}</a>
    </div>
  </div>
</template>

<script>
import CollapseTriangle from "../CollapseTriangle";

export default {
  components: {
    CollapseTriangle
  },
  props: ["item", "editing", "rootOrdinalDisplay"],
  methods: {
    toggleSectionExpanded: function() {
      this.$store.dispatch('table_of_contents/toggleCollapsed', {id:this.item.id});
    }
  },
  computed: {
    collapsed: function() {
      return this.item.collapsed;
    },
    url: function() {
      return this.editing ? this.item.edit_url : this.item.url;
    }
  }
};
</script>