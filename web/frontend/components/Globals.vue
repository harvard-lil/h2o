<template>
    
</template>

<script>
import { createNamespacedHelpers } from "vuex";
const { mapMutations } = createNamespacedHelpers("globals");

export default {
    props: ["casebook","section"],
    created: function() {
        this.setCasebook(this.casebook);
        this.setSection(this.section);
    },
    methods: {...mapMutations(['setCasebook','setSection'])}
}
</script>