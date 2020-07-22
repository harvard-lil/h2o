<template>
  <div class="input-group">
  <select class="transmute-dropdown select-css" v-model="resource_type">
    <option value="Case" v-if="item.resource_type === 'Case'">Case</option>
    <option value="Temp" v-else>Case</option>
    <option value="Section">Section</option>
    <option value="TextBlock">Text</option>
    <option value="Link">Link</option>
  </select>
</div>
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

<style lang="scss" scoped> 
.select-css {
	display: block;
	color: #444;
	padding: .5em 1.6em .4em 1em;
	width: 100%;
	max-width: 100%;
	box-sizing: border-box;
	margin: 0;
	border: 1px solid #aaa;
	box-shadow: 0 1px 0 1px rgba(0,0,0,.04);
	border-radius: .25em;
	-moz-appearance: none;
	-webkit-appearance: none;
	appearance: none;
	background-color: white;
	background-image: url('data:image/svg+xml;charset=US-ASCII,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%22292.4%22%20height%3D%22292.4%22%3E%3Cpath%20fill%3D%22%23007CB2%22%20d%3D%22M287%2069.4a17.6%2017.6%200%200%200-13-5.4H18.4c-5%200-9.3%201.8-12.9%205.4A17.6%2017.6%200%200%200%200%2082.2c0%205%201.8%209.3%205.4%2012.9l128%20127.9c3.6%203.6%207.8%205.4%2012.8%205.4s9.2-1.8%2012.8-5.4L287%2095c3.5-3.5%205.4-7.8%205.4-12.8%200-5-1.9-9.2-5.5-12.8z%22%2F%3E%3C%2Fsvg%3E');
	background-repeat: no-repeat, repeat;
	background-position: right .7em top 50%, 0 0;
	background-size: .65em auto, 100%;
}
.select-css::-ms-expand {
	display: none;
}
.select-css:hover {
	border-color: #888;
}
.select-css:focus {
	border-color: #aaa;
	box-shadow: 0 0 1px 3px rgba(59, 153, 252, .7);
	box-shadow: 0 0 0 3px -moz-mac-focusring;
	color: #222;
	outline: none;
}
.select-css option {
	font-weight:normal;
}


</style>
