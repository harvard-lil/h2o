<template>
  <div id="publish-button">
    <button type="button" 
            class="action publish one-line" 
            :disabled="disabled"
            :title="disabled ? 'Some resources are incomplete. Finalize Entries below.' : 'Publish'"
            @click="attemptPublish">
            Publish
    </button>
    <Modal v-if="showModal" @close="showModal = false">
      <template slot="title">Confirm Publish</template>
      <template slot="body">
        <p>Are you ready to publish your book?</p>
        
        <div v-if=publishCheck.isVerifiedProfessor id="prof-prompt">
          You're almost ready to publish your book! The following elements are
          optional, but can make your book more discoverable by students and
          colleagues:
          <ul class="fa-ul">
            <li v-if="this.publishCheck.coverImageFlag">
              <span v-if="this.publishCheck.coverImageExists" class="fa-li"><font-awesome-icon icon="fa-solid fa-check fa-fw" /></span>
              <span v-else class="fa-li"><font-awesome-icon icon="fa-solid fa-xmark fa-fw" /></span>
              Cover Photo
            </li>
            <li>
              <span v-if="this.publishCheck.descriptionExists" class="fa-li"><font-awesome-icon icon="fa-solid fa-check fa-fw" /></span>
              <span v-else class="fa-li"><font-awesome-icon icon="fa-solid fa-xmark fa-fw" /></span>
              Description 
            </li>
          </ul>
          We also encourage you to share your work with your colleagues or on
          social media! Your book is an important contribution to open education
          for law and we hope you'll help others find it and use it in their own
          classrooms. Because you are a verified professor, your book will
          automatically be surfaced on H2O's search page and will appear in web
          searches.
        </div>

        <div class="modal-footer">
          <button class="modal-button cancel" @click="cancelPublish">Go Back</button>
          <button class="modal-button confirm" @click="confirmPublish">Publish</button>
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
  props: {
    disabled: Boolean,
    publishCheck: Object
  },
  data() {
    return {
    showModal: false,
    csrftoken: getCookie("csrftoken"),
    liCheck: [
      {text: "Cover image added", val: this.publishCheck.coverImageExists},
      {text: "Description added", val: this.publishCheck.descriptionExists},
    ]
      
  }},
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

.casebook-actions button.action.publish[disabled] {
  filter: grayscale(1.0);    
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
