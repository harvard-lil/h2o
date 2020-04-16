<template>
<div id="section-cloner">
  <button class="action clone-casebook-nodes" data-disable-with="Clone-Node" v-on:click="displayModal()">Clone Nodes</button>
  <Modal v-if="showModal"
            @close="showModal = false">
    <template slot="title">Clone Section To Casebook</template>
    <template slot="body">
      <p>Select a casebook to clone <em>{{sectionSource}}</em> to</p>
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
    sectionSource: {type: String}
  },
  data: () => ({showModal: false,
                csrftoken: getCookie('csrftoken')}),
  methods: {
    displayModal: function displayModal() {
      this.showModal = true;
    }
  }
};

</script>

<style lang="scss">
.casebook-actions button.action.clone-casebook-nodes {
    background-image: url(http://localhost:8080/static/dist/img/clone.fc6eb4b4.svg);
    border: none;
}

ul.clone-target-list {
    list-style: none;
    overflow: scroll;
    max-height: 600px;
    li {
        button.link {
            background-color:white;
            border: 0;
            text-decoration: underline;
            color: rgba(80, 172, 50, 1);
            &:hover {
                font-weight: bold;
            }
        }
    }
}
</style>
