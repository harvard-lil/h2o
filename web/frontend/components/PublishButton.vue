<template>
  <div id="publish-button">
    <button type="button"
            class="action publish one-line"
            :disabled="disabled"
            :title="disabled ? 'Some resources are incomplete. Finalize entries below.' : 'Publish'"
            @click="attemptPublish">
            Publish
    </button>
    <Modal v-if="showModal" @close="showModal = false">
      <template slot="title">Confirm Publish</template>
      <template slot="body">

        <div v-if="!publishSuccess">
          <div v-if="publishCheck.isVerifiedProfessor" id="prof-prompt">
            <p>
              You're almost ready to publish your book! The following elements are
            optional, but can make your book more discoverable by students and
            colleagues:
            </p>
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

          </div>
          <div v-else>
            <p>Are you ready to publish your book?</p>
          </div>
        </div>
        <div v-else>
          <h3>Your book is published!</h3>

          <p>Use this link to share your book with students and colleagues: {{this.canonicalUrl}}</p>
          <p>
          Because you are a verified professor your book will automatically be surfaced in H2O's search page and will appear in web searches. We also encourage you to share your book with your colleagues, however you prefer to reach them. There is a growing community around open education for law and we hope you'll help others find and use your book in their classrooms.
          </p>

        </div>

      </template>
      <template slot="footer">
          <button v-show="!publishSuccess" class="modal-button cancel" @click="cancelPublish">Go Back</button>
          <button v-show="!publishSuccess" class="modal-button confirm" @click="confirmPublish">Publish</button>
          <button v-show="publishSuccess"  class="modal-button confirm" @click="viewPublished">OK</button>
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
      ],
      publishSuccess: false,
      canonicalUrl: null
    }
  },
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
      const url = `/casebooks/${this.casebook}/publish/`;

      Axios.post(url, {}).then(
        this.handleSubmitResponse,
        this.handleSubmitErrors
      );
    },
    viewPublished: function () {
      if (this.canonicalUrl) {
        window.location.href = this.canonicalUrl;
      }
    },
    handleSubmitResponse: function handleSubmitResponse(response) {
      this.publishSuccess = true;
      this.canonicalUrl = response.data.url;
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
