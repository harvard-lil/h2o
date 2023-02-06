<template>

    <button class="action export-pdf" @click="exportPdf">Export PDF<br/><small>BETA</small></button>

</template>

<script>
import Axios from "../config/axios";

export default {
  components: {
  },
  props: {
    url: String,
  },
  computed: {
    casebook: function() {
      return this.$store.getters["globals/casebook"]()
    }
  },
  methods: {
    exportPdf() {
      Axios.post(`/api/casebooks/${this.casebook}/export-pdf.json`);
    }
  }
}
</script>
