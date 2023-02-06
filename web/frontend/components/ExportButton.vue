<template>
    <div>
        <button class="action export-pdf" @click="exportPdf">
            Export PDF<br /><small>BETA</small>
        </button>
        <Modal v-if="showModal" @close="showModal = false">
            <template slot="title">
                <div>Exporting as PDF...</div>
            </template>
            <template slot="body"> Exporting ... </template>
            <template slot="footer"> </template>
        </Modal>
    </div>
</template>

<script>
import Axios from "../config/axios";
import Modal from "./Modal";

const RETRY_INTERVAL = 1_000;
const MAX_RETRIES = 10;

export default {
    components: {
        Modal,
    },
    data() {
        return {
            showModal: false,
            taskId: null,
            completed: false,
            retries: 0,
            result: null,
        };
    },
    computed: {
        casebook: function () {
            return this.$store.getters["globals/casebook"]();
        },
    },
    methods: {
        exportPdf() {
            Axios.post(`/api/casebooks/${this.casebook}/export-pdf.json`).then((res) => {
              this.taskId = res.data;
              this.showModal = true;
              this.pollForStatus();
            });

        },
        pollForStatus() {
            Axios.get(
                `/api/casebooks/${this.casebook}/export-pdf.json`, {
                  params: {task_id: this.taskId}
                }
            ).then((res) => {
                this.result = {succeeded: res.data};
                this.completed = true;
                console.log(res.data)
            }).catch((err) => {
              if (err.response.status === 404) {
                this.retries++;
                if (this.retries < MAX_RETRIES) {
                  setTimeout(() => this.pollForStatus(), RETRY_INTERVAL)
                }
                else {
                  this.result = {error: "Maximum retries exceeded."};
                  this.completed = true;
                }
              }
            });
        },
    },
};
</script>
