<template>
<div id="section-cloner">
  <button class="action clone-casebook-nodes" data-disable-with="Clone-Node" v-on:click="displayModal()">Clone {{properType()}}</button>
  <Modal v-if="showModal"
            @close="showModal = false">
    <template slot="title">Clone {{properType()}} To Casebook</template>
    <template slot="body">
      <p>The {{sectionType}} "<em>{{sectionSource}}</em>" will be copied to the casebook you select below:</p>
      <ul class="clone-target-list">
        <li v-for="cb in casebookTargets" v-bind:key="cb.form_target">
          <form :action="cb.form_target" method="POST">
            <input type="hidden" name="csrfmiddlewaretoken" :value="csrftoken" />
            <button class="link" type="submit">{{cb.title}}</button>
          </form>
        </li>
      </ul>
    </template>
  </Modal>
</div>
</template>

<script>
import Modal from "./Modal";

function getCookie(name) {
  var cookieValue = null;
  if (document.cookie && document.cookie !== '') {
    var cookies = document.cookie.split(';');
    for (var i = 0; i < cookies.length; i++) {
      var cookie = jQuery.trim(cookies[i]);
      if (cookie.substring(0, name.length + 1) === (name + '=')) {
        cookieValue = decodeURIComponent(cookie.substring(name.length + 1));
        break;
      }
    }
  }
  return cookieValue;
}

export default {
  components: {
    Modal
  },
  props:{
    casebookTargets: {type: Array},
    sectionSource: {type: String},
    sectionType: {type: String}
  },
  data: () => ({showModal: false,
                csrftoken: getCookie('csrftoken')}),
  methods: {
    displayModal: function displayModal() {
      this.showModal = true;
    },
    properType: function properType() {
      return this.sectionType[0].toUpperCase() + this.sectionType.substr(1);
    }
  }
};

</script>

<style lang="scss">
.casebook-actions button.action.clone-casebook-nodes {
    background-image: url('~static/images/ui/casebook/clone.svg');
    border: none;
}

ul.clone-target-list {
    list-style: none;
    overflow: scroll;
    max-height: 600px;
    padding-top:4px;
    li {
        margin-bottom: .5rem;
        margin-right: 40px;
        
        button.link {
            padding:8px;
            border: 1px solid grey;
            font-weight: bold;
            text-align: left;
            width: 100%;
            background-color: white;
            &:hover {
                background-color: #EEEEEE;
            }
        }
    }
}
</style>
