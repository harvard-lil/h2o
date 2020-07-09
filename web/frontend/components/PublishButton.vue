<template>
  <div id="publish-button">
    <button type="button" class="action publish one-line" @click="attemptPublish">Publish</button>
    <Modal v-if="showModal" @close="showModal = false">
      <template slot="title">Confirm Publish</template>
      <template slot="body">
        <p>Are you ready to publish your book?</p>
        <div class="modal-footer">
          <button class="modal-button cancel" @click="cancelPublish">No</button>
          <button class="modal-button confirm" @click="confirmPublish">Yes</button>
        </div>
      </template>
    </Modal>
  </div>
</template>

<script>
import Modal from "./Modal";
import Axios from "../config/axios";


function getCookie(name) {
  var cookieValue = null;
  if (document.cookie && document.cookie !== "") {
    var cookies = document.cookie.split(";");
    for (var i = 0; i < cookies.length; i++) {
      var cookie = jQuery.trim(cookies[i]);
      if (cookie.substring(0, name.length + 1) === name + "=") {
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
  props: {},
  data: () => ({
    showModal: false,
    csrftoken: getCookie("csrftoken")
  }),
  computed: {
      casebook: function() {
          return this.$store.getters['globals/casebook']();
      }
  },
  methods: {
    attemptPublish: function() {
      this.showModal = true;
    },
    cancelPublish: function() {
      this.showModal = false;
    },
    confirmPublish: function() {
      const url = `/casebooks/${this.casebook}`;
      const data = {content_casebook: {public: true}};
      Axios.patch(url, data).then(
        this.handleSubmitResponse,
        this.handleSubmitErrors
      );
    },
    handleSubmitResponse: function handleSubmitResponse(response) {
      let location = response.request.responseURL;
      window.location.href = location;
      this.errors = {};
    },
    handleSubmitErrors: function handleSubmitErrors(error) {
      if (error.response.data) {
        this.errors = error.response.data;
      }
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
  padding-top: 4px;
  li {
    margin-bottom: 0.5rem;
    margin-right: 40px;

    button.link {
      padding: 8px;
      border: 1px solid grey;
      font-weight: bold;
      text-align: left;
      width: 100%;
      background-color: white;
      &:hover {
        background-color: #eeeeee;
      }
    }
  }
}
</style>
