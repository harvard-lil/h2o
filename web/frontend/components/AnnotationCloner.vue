<template>
<div id="annotation-cloner">
  <button class="action annotate-casebook-nodes" data-disable-with="Clone-Node" v-on:click="displayModal()">Annotate {{properType()}}</button>
  <Modal v-if="showModal"
            @close="showModal = false">
    <template class="modal-title" slot="title">Copying {{properType()}} for Annotation</template>
    <template class="modal-body" slot="body">
      <p>Choose a book you would like  "<em>{{sectionSource}}</em>" to be copied into : </p>
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
.casebook-actions button.action.annotate-casebook-nodes {
    background-image: url('~static/images/annotation-icon.svg');
    border: none;
}
.annotate-casebook{
  background-image: url('~static/images/annotation-icon.svg');
  border: none;
}
.modal-title{
  padding-left: 30px;
  padding-top: 5px;
  font-weight:600;
  text-align: center;
}

.modal-body{
  padding-left: 40px;
}

ul.clone-target-list {
    list-style: none;
    overflow: scroll;
    max-height: 600px;
    padding-top:4px;
    padding-left: 0px;
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
