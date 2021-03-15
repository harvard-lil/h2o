<template>
    
</template>

<script>
import { createNamespacedHelpers } from "vuex";
const globalStore = createNamespacedHelpers("globals");
const searchStore = createNamespacedHelpers("case_search");

export default {
    props: ['casebook','section', 'searchSources'],
    created: function() {
        this.setCasebook(this.casebook);
      this.setSection(this.section);
      this.setSources(this.searchSources);
    },
  methods: {...globalStore.mapMutations(['setCasebook','setSection']),
            ...searchStore.mapMutations(['setSources'])}
}
</script>
