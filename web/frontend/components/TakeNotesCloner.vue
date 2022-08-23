<template>
<div id="take-notes-cloner">
  <button class="action annotate-casebook-nodes" data-disable-with="Clone-Node" v-on:click="displayModal()">Take notes</button>
  <Modal v-if="showModal"
            @close="showModal = false">
    <template class="modal-title" slot="title">
      <span class="take-notes-icon"></span>
      <h4>Copying {{properType()}} for Taking Notes</h4>
    </template>
    <template class="modal-body-take-notes" slot="body">
      <p class="take-notes-cloner-text"> <b> To Take Notes, you need to Create a Copy.<br/><br/> Choose a book</b>  you would like  "<em>{{sectionSource}}</em>" to be copied into : </p>
      <ul class="take-notes-target-list">
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
import { get_csrf_token } from "../legacy/lib/helpers";

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
                csrftoken: get_csrf_token()}),
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
    background-image: url('~static/images/take-notes-icon.svg');
    border: none;
}
.annotate-casebook{
  background-image: url('~static/images/take-notes-icon.svg');
  border: none;
}
.modal-title{
  padding-left: 30px;
  padding-top: 5px;
  font-weight:600;
  text-align: center;
  display:flex;
  flex-direction: row;
  justify-content: center;
  .take-notes-icon{
    background-image: url('~static/images/take-notes-icon.svg');
    display: inline-block;
    height: 35px;
    width: 35px;
  }
  h4{
    margin-left: 10px;
  }
}

.take-notes-cloner-text{
  padding-left: 40px;
  p{
    font-size: 16px;
    padding: 10px;
    margin-right: 40px;
  }
  b{
    color:#3E72D8;
  }
}

ul.take-notes-target-list {
    list-style: none;
    overflow: scroll;
    max-height: 600px;
    padding-top:4px;
    padding-left: 40px;
    li {
        margin-bottom: .5rem;
        margin-right: 40px;
        
        button.link {
            padding:8px;
            border: 0.5px solid grey;
            font-weight: bold;
            text-align: left;
            width: 100%;
            background-color: white;
            &:hover {
                background-color: rgb(202, 226, 249);
            }
            &:focus{
                background-color: rgb(202, 226, 249);;
                outline:none;
            }
        }
    }
}
</style>
