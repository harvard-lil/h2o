<template>
    <div>
        <button class="action export-pdf" @click="exportPdf">
            Export PDF<br /><small>BETA</small>
        </button>
        <Modal v-if="showModal" @close="close">
            <template slot="title">
                <h2 class="export-modal">Exporting as PDF...</h2>
            </template>
            <template slot="body">
                <div class="export-modal">
                    <div
                        class="spinner export-spinner"
                        v-show="!this.response"
                    >
                        <div class="bounce1"></div>
                        <div class="bounce2"></div>
                        <div class="bounce3"></div>
                    </div>
                    <p>
                        {{ this.response }}

                    </p>
                    <p v-show="this.url">
                      <a v-bind:href="this.url">⬇ Download PDF</a>
                    </p>
                </div>
            </template>
        </Modal>
    </div>
</template>

<script>
import Axios from "../config/axios";
import Modal from "./Modal";

const RETRY_INTERVAL = 1_000;
const MAX_RETRIES = 20;

function init() {
    return {
        showModal: false,
        taskId: null,
        retries: 0,
        result: null,
        url: null,
    };
}
export default {
    components: {
        Modal,
    },
    data() {
        return init();
    },
    computed: {
        casebook: function () {
            return this.$store.getters["globals/casebook"]();
        },
        response: function () {
            if (this.result) {
                if (this.result.succeeded) {
                    return `✅ Success! Your PDF file is available now.`;
                }
                if (this.result.timeout) {
                    return `❌ PDF export did not succeed—export did not finish in time.`;
                } else {
                    return `❌ PDF export did not succeed: ${this.result.error}`;
                }
            }
            return null;
        },
    },
    methods: {
        close() {
          this.showModal = false;
          Object.assign(this.$data, init());
        },
        exportPdf() {
            Axios.post(`/api/casebooks/${this.casebook}/export-pdf.json`).then(
                (res) => {
                    this.taskId = res.data;
                    this.showModal = true;
                    this.pollForStatus();
                }
            );
        },
        pollForStatus() {
            Axios.get(`/api/casebooks/${this.casebook}/export-pdf.json`, {
                params: { task_id: this.taskId },
            })
                .then((res) => {
                    this.result = { succeeded: res.data };
                    this.url = this.result.succeeded;
                })
                .catch((err) => {
                    if (err.response.status === 404) {
                        this.retries++;
                        if (this.retries < MAX_RETRIES) {
                            setTimeout(this.pollForStatus, RETRY_INTERVAL);
                        } else {
                            this.result = {
                                timeout: "Maximum retries exceeded.",
                            };
                        }
                    } else {
                        this.result = { error: err.response.data };
                    }
                });
        },
    },
};
</script>

<style lang="scss">
.export-spinner {
  text-align: center;
  margin: auto;
}
.modal-body .export-modal {
  padding: 5rem;
  text-align: center;
  font-size: 20px;
}
h2.export-modal {
  font-size: 30px;
}
</style>