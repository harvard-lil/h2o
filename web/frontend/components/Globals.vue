<template>
    
</template>

<script>
import { createNamespacedHelpers } from "vuex";
const globalStore = createNamespacedHelpers("globals");
const searchStore = createNamespacedHelpers("case_search");

export default {
  props: ['casebook','section', 'searchSources'],
  created: function() {
    if (this.casebook) this.setCasebook(this.casebook);
    if (this.section) this.setSection(this.section);
    if (this.searchSources) this.setSources(this.searchSources);
    },
  methods: {...globalStore.mapMutations(['setCasebook','setSection']),
            ...searchStore.mapMutations(['setSources'])}
}
</script>
