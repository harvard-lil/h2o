<template>
<div
  :id="anchor"
  v-bind:class="['listing-wrapper', showDelete ? 'delete-confirm' : '', animated, dimmed]"
  v-click-outside.stop.prevent="dismissAudit"
  >
  <vue-nestable-handle :item="item">
    <div v-bind:class="{'listing':true, 'resource':true, 'temporary': item.resource_type == 'Temp', 'editing': 'editing'}" v-if="isResource">
      <div class="list-left">
        <div class="section-number">{{rootOrdinalDisplay}}</div>
        
        <div class="resource-container" v-if="item.resource_type==='Case'">
          <a :href="url" class="section-title case-section-title">{{ item.title }}</a>
          <div class="case-metadata-container">
            <div class="resource-case">{{ item.citation }}</div>
            <div class="resource-date">{{ item.decision_date }}</div>
          </div>
        </div>
        
        <div class="resource-container" v-else>
          <a :href="url" class="section-title">{{ item.title }}</a>
        </div>
      </div>
      
      <div class="list-right">
        <div v-if="needsToSpecifyCase">
          <button
            class="btn btn-sm specify-case-button"
            @click="auditThisCase"
            value="Specify Case"
                  >Specify Case</button>
        </div>
        <div class="resource-type-container">
          <div v-if="item.is_transmutable && editing">
            <entry-transmuter :item="item"></entry-transmuter>
          </div>
          <div v-else
               v-bind:class="{'resource-type': true, 'temporary': item.resource_type === 'Temp'}"
               >{{ item.resource_type === 'TextBlock' ? 'Text' : item.resource_type }}</div>
        </div>
            <div v-bind:class="{'actions': !showDelete, 'actions-extra': showDelete}" v-if="editing">
      <button
        :aria-label="'Delete ' +item.title"
        class="action-delete"
        v-on:click="markForDeletion"
        v-if="!showDelete"
        ></button>
      <div class="action-confirmation" v-else>
        <div class="action-align-resource">
          <button
            class="action-confirm-delete btn btn-danger"
            v-on:click="confirmDeletion"
            >Delete {{item.resource_type !== null && item.resource_type !== 'Section' ? '' : 'section and all contents'}}</button>
          <button class="action-cancel-delete btn" v-on:click="cancelDeletion" v-focus>Keep</button>
        </div>
      </div>
    </div>

      </div>
    </div>
    
    <div class="listing section" v-bind:class="['listing', 'section' ,item.children.length > 0 ? 'child-present' : 'child-free', editing ? 'editing' : '' ]" v-else>
      <div class="list-left">
        <button
          aria-role="heading"
          :aria-expanded="!collapsed ? 'true' : 'false'"
          :aria-label="collapsed ? 'expand ' + item.title : 'collapse ' + item.title"
          v-on:click="toggleSectionExpanded"
          class="action-expand"
          v-if="item.children.length > 0 || collapsed"
          >
          <collapse-triangle :collapsed="collapsed" />
        </button>
        <div class="section-number">{{rootOrdinalDisplay}}</div>
        <div class="section-container">
          <!--      -->
          <div class="section-title">
            <a :href="url" class="section-title">{{ item.title }}</a>
          </div>
          
        </div>
      </div>
      <div class="list-right">
        <div class="resource-type-container" v-if="item.is_transmutable && editing">
          <entry-transmuter :item="item"></entry-transmuter>
        </div>
        <div v-else>
          &nbsp;
        </div>
    <div v-bind:class="{'actions': !showDelete, 'actions-extra': showDelete}"  v-if="editing">
      <button
        :aria-label="'Delete ' +item.title"
        class="action-delete"
        v-on:click="markForDeletion"
        v-if="!showDelete"
        ></button>
      <div class="action-confirmation" v-else>
        <div class="action-align-section">
          <button
            class="action-confirm-delete btn btn-danger"
            v-on:click="confirmDeletion"
            >Delete {{item.resource_type !== null && item.resource_type !== 'Section' ? '' : 'section and all contents'}}</button>
          <button class="action-cancel-delete btn" v-on:click="cancelDeletion" v-focus>Keep</button>
        </div>
      </div>
    </div>


      </div>
    </div>
    
    
  </vue-nestable-handle>
  <div class="audit-drawer" v-if="item.audit && item.resource_type === 'Temp'">
    <entry-auditor :item="item"></entry-auditor>
    </div>
  </div>
</template>

<script>
import EntryAuditor from "./EntryAuditor";
import EntryTransmuter from "./EntryTransmuter";
import CollapseTriangle from "../CollapseTriangle";
import Vue from "vue";
import { VueNestable, VueNestableHandle } from "vue-nestable";
import vClickOutside from "v-click-outside";
import { createNamespacedHelpers } from "vuex";
const { mapActions } = createNamespacedHelpers("table_of_contents");

Vue.use(VueNestable);
Vue.use(vClickOutside);

export default {
    components: {
        EntryAuditor,
        EntryTransmuter,
        VueNestableHandle,
        CollapseTriangle
    },
    props: ["item", "rootOrdinalDisplay", "editing"],
    data: () => ({ showDelete: false }),
    computed: {
        needsToSpecifyCase: function() {
            return this.item.resource_type === 'Temp' && !this.item.audit;
        },
        collapsed: function() {
            return this.item.collapsed;
        },
        url: function() {
            return this.editing ?  this.item.edit_url : this.item.url;
        },
        dimmed: function() {
            return !this.item.audit && this.$store.getters["globals/inAuditMode"]()
                ? "dimmed"
                : "";
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
        auditThisCase: function() {
            this.$store.dispatch('table_of_contents/setAudit', {id: this.item.id });
        },
    toggleSectionExpanded: function() {
      this.$store.dispatch('table_of_contents/toggleCollapsed', {id:this.item.id});
    },
    dismissAudit: function() {
      if (!this.item.audit || !this.$store.getters["globals/inAuditMode"]()) {
        return;
      }
      this.$store.commit("globals/setAuditMode", false);
      this.$store.dispatch("table_of_contents/clearAudit", {
        id: this.item.id
      });
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
    opacity: 0.5;
}

.audit-drawer {
    margin: 0 1rem 1rem 1rem;
    border-left: 2px solid black;
    border-bottom: 2px solid black;
    border-right: 2px solid black;
    padding: 1rem;
    background-color: white;
}

.listing.resource.temporary {
    outline: 2px solid red;
}

.action-confirm-delete {
    border: 1px solid black;
}

.action-align-resource {
    width: 156px;
    margin-right: -16px;
}
.action-align-section {
    width: 316px;
    margin-right:-16px;
}
.specify-case-button {
    margin-right: 1rem;
}
</style>
