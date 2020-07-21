<template>
  <select class="transmute-dropdown" v-model="resource_type">
    <option value="Case" v-if="item.resource_type === 'Case'">Case</option>
    <option value="Temp" v-else>Case</option>
    <option value="Section">Section</option>
    <option value="TextBlock">Text</option>
    <option value="Link">Link</option>
  </select>
</template>

<script>
import urls from "libs/urls";
import Axios from "../../config/axios";

export default {
    data: () => ({ resource_type: "" }),
    props: ["item"],
    mounted: function() {
        this.resource_type = this.item.resource_type;
    },
    methods: {
        changeType: urls.url("resource"),
        refreshTOC: function() {
            const casebook = this.$store.getters['globals/casebook']();
            const subsection = this.$store.getters['globals/section']();
            this.$store.dispatch('table_of_contents/fetch', { casebook, subsection });
      }
  },
  computed: {
    casebook: function() {
      return this.$store.getters["globals/casebook"]();
    }
  },
  watch: {
    item: function(newVal) {
      this.resource_type = newVal.resource_type;
    },
    resource_type: function(newVal) {
      if (newVal === this.item.resource_type) {
        return;
      }
      const data = { from: this.item.resource_type, to: newVal == 'Temp' ? 'Case' : newVal };
        Axios.patch(this.item.url, data).then(this.refreshTOC, this.refreshTOC);
    }
  }
};
</script>
