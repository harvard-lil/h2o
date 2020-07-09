<template>
  <div
    :id="anchor"
    v-bind:class="['listing-wrapper', showDelete ? 'delete-confirm' : '', animated, dimmed]"
    v-click-outside.stop.prevent="dismissAudit"
  >
    <vue-nestable-handle :item="item">
        <entry-resource
          v-if="isResource"
          :item="item"
          :root-ordinal-display="rootOrdinalDisplay"
          :editing="editing"
        />
        <entry-section
          v-else
          :item="item"
          :root-ordinal-display="rootOrdinalDisplay"
          :editing="editing"
          v-on="$listeners"
        />

        <div class="actions" v-if="editing">
          <button
            :aria-label="'Delete ' +item.title"
            class="action-delete"
            v-on:click="markForDeletion"
            v-if="!showDelete"
          ></button>
          <div class="action-confirmation" v-else>
            <div class="action-align">
              <button
                class="action-confirm-delete"
                v-on:click="confirmDeletion"
              >Delete {{item.resource_type !== null && item.resource_type !== 'Section' ? '' : 'section and all contents'}}</button>
              <button class="action-cancel-delete" v-on:click="cancelDeletion" v-focus>Keep</button>
            </div>
          </div>
        </div>
    </vue-nestable-handle>

    <div class="audit-drawer" v-if="item.audit">
      <entry-auditor :item="item"></entry-auditor>
    </div>
  </div>
</template>

<script>
import EntryResource from "./EntryResource";
import EntrySection from "./EntrySection";
import EntryAuditor from "./EntryAuditor";
import Vue from 'vue';
import {VueNestable, VueNestableHandle} from "vue-nestable";
import vClickOutside from 'v-click-outside'
import { createNamespacedHelpers } from "vuex";
const { mapActions } = createNamespacedHelpers("table_of_contents");

Vue.use(VueNestable);
Vue.use(vClickOutside);

export default {
  components: {
    EntryResource,
    EntrySection,
    EntryAuditor,
    VueNestableHandle
  },
  props: ["item", "rootOrdinalDisplay", "editing"],
  data: () => ({ showDelete: false }),
  computed: {
    dimmed: function() {
      return (!this.item.audit && this.$store.getters['globals/inAuditMode']()) ? 'dimmed' : '';
    },
    animated: function() {
      return this.item.audit ? "" : this.item.animationState;
    },
    animatingLoading: function() {
      return this.animationState && this.animationState === "loading";
    },
    animatingLoaded: function() {
      return this.animationState && this.animationState === "loaded";
    },
    isResource: function() {
      return (
        this.item.resource_type !== null &&
        this.item.resource_type !== "" &&
        this.item.resource_type !== "Section"
      );
    },
    anchor: function() {
      const url_parts = this.item.url.split("/");
      return url_parts[url_parts.length - 2];
    },
    casebook: function() {
      return this.$store.getters["globals/casebook"]();
    },
    section: function() {
      return this.$store.getters["globals/section"]();
    }
  },
  methods: {
    dismissAudit: function() {
      if (! this.item.audit || ! this.$store.getters['globals/inAuditMode']()) {
        return;
      }
      this.$store.commit('globals/setAuditMode', false);
      this.$store.dispatch('table_of_contents/clearAudit', {id: this.item.id});
    },
    ...mapActions(["deleteNode"]),
    markForDeletion: function() {
      this.showDelete = true;
    },
    cancelDeletion: function() {
      this.showDelete = false;
    },
    confirmDeletion: function({ id }) {
      this.deleteNode({
        casebook: this.casebook,
        rootNode: this.section || this.casebook,
        targetId: this.item.id
      });
    }
  }
};
</script>

<style lang="scss" scoped>
.loading {
  display: none;
}
.loaded {
  animation-name: fadeInUp;
  animation-duration: 200ms;
}

@keyframes fadeInUp {
  0% {
    opacity: 0;
    transform: translateY(100%);
  }
  100% {
    opacity: 1;
    transform: translateY(0%);
  }
}

@keyframes fadeInDown {
  0% {
    opacity: 0;
    transform: translateY(0%);
  }
  100% {
    opacity: 1;
    transform: translateY(100%);
  }
}

.dimmed {
  opacity:0.5;
}

.audit-drawer {
  //animation-name: fadeInDown;
  //animation-duration: 200ms;
  margin: 0 1rem 1rem 1rem;
  border-left: 2px solid black;
  border-bottom: 2px solid black;
  border-right: 2px solid black;
  padding: 1rem;
  background-color: white;
}
</style>