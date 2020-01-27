<template>
  <div class="table-of-contents" v-bind:class="{'editable':editing}">
    <vue-nestable
      v-model="toc"
      :hooks="{'beforeMove':canMove}"
      v-on:change="moveSubsection"
      v-if="dataReady">
      <vue-nestable-handle slot-scope="{ item }" :item="item" class="collapsed" v-if="editing">
        <div v-bind:class="{'listing-wrapper':true, 'delete-confirm': promptForDelete({id:item.id})}">
          <div class="listing resource" v-if="item.resource_type !== null">
            <div class="section-number"></div>
            <div class="resource-container" v-if="item.resource_type==='Case'">
              <a :href="item.edit_url" class="section-title case-section-title">{{ item.title }}</a>
              <div class="case-metadata-container">
                <div class="resource-case">{{ item.citation }}</div>
                <div class="resource-date">{{ item.decision_date }}</div>
              </div>
            </div>
            <div class="resource-container" v-else-if="item.resource_type === 'TextBlock'">
              <a :href="item.edit_url" class="section-title">{{ item.title }}</a>
            </div>
            <div class="resource-container" v-else-if="item.resource_type === 'Link'">
              <a :href="item.edit_url" class="section-title">{{ item.title }}</a>
            </div>
            <div class="resource-type-container">
              <div
                class="resource-type"
              >{{ item.resource_type === 'TextBlock' ? 'Text' : item.resource_type }}</div>
            </div>
          </div>
          <div class="listing section" v-else>
            <div v-on:click="toggleSectionExpanded({id:item.id})" class="action-expand">
              <collapse-triangle :collapsed="isCollapsed({id:item.id})" />
            </div>
            <div class="section-number"></div>
            <div class="section-title">
              <a :href="item.edit_url" class="section-title">{{ item.title }}</a>
            </div>
          </div>
          <div class="actions">
            <button
              class="action-delete"
              v-on:click="markForDeletion({id:item.id})"
              v-if="!promptForDelete({id:item.id})"
            ></button>
            <div class="action-confirmation" v-else>
              <div class="action-align">
                <button
                  class="action-confirm-delete"
                  v-on:click="confirmDeletion({id:item.id})"
                >Delete</button>
                <button class="action-cancel-delete" v-on:click="cancelDeletion({id:item.id})">Keep</button>
              </div>
            </div>
          </div>
        </div>
      </vue-nestable-handle>
      <div class="listing-wrapper" v-else>
        <div class="listing resource" v-if="item.resource_type !== null">
          <div class="section-number"></div>
          <div class="resource-container" v-if="item.resource_type==='Case'">
            <a :href="item.edit_url" class="section-title case-section-title">{{ item.title }}</a>
            <div class="case-metadata-container">
              <div class="resource-case">{{ item.citation }}</div>
              <div class="resource-date">{{ item.decision_date }}</div>
            </div>
          </div>
          <div class="resource-container" v-else-if="item.resource_type === 'TextBlock'">
            <a :href="item.edit_url" class="section-title">{{ item.title }}</a>
          </div>
          <div class="resource-container" v-else-if="item.resource_type === 'Link'">
            <a :href="item.edit_url" class="section-title">{{ item.title }}</a>
          </div>
          <div class="resource-type-container">
            <div class="resource-type">{{ item.resource_type === 'TextBlock' ? 'Text' : item.resource_type }}</div>
          </div>
        </div>
        <div class="listing section" v-else>
          <div v-on:click="toggleSectionExpanded({id:item.id})" class="action-expand">
            <collapse-triangle :collapsed="isCollapsed({id:item.id})" />
          </div>
          <div class="section-number"></div>
          <div class="section-title">
            <a :href="item.edit_url" class="section-title">{{ item.title }}</a>
          </div>
        </div>
      </div>
    </vue-nestable>
  </div>
</template>
                                
<script>
import Vue from "vue";
import { VueNestable, VueNestableHandle } from "vue-nestable";
import CollapseTriangle from "./CollapseTriangle";
import { createNamespacedHelpers } from "vuex";
const { mapActions, mapMutations } = createNamespacedHelpers(
  "table_of_contents"
);

export default {
  components: {
    VueNestable,
    VueNestableHandle,
    CollapseTriangle
  },
  data: () => ({
    needsDeleteConfirmation: {},
    collapsedSections: {}
  }),
  computed: {
    targetId: function() {
      return this.rootId || this.casebook;
    },
    toc: {
      get: function() {
        const candidate = this.$store.getters["table_of_contents/getNode"](
          this.targetId
        );
        const omit = this.collapsedSections;
        function disownChildren(node) {
          if (!node) {
            return node;
          }
          let { children, id } = node;
          if (id in omit) {
            return { ...node, children: [] };
          } else {
            return { ...node, children: children.map(disownChildren) };
          }
        }
        let list = disownChildren(candidate);
        return list && list.children;
      },
      set: function(newVal) {
        this.shuffle({ id: this.targetId, children: newVal });
      }
    },
    dataReady: function() {
      return this.toc !== [null] && this.toc !== null;
    }
  },
  methods: {
    ...mapActions(["fetch", "deleteNode", "commitShuffle", "moveNode"]),
    ...mapMutations(["shuffle"]),
    canMove: function({ dragItem, pathFrom, pathTo }) {
      if (pathTo.length === 1) {
        return true;
      }
      let res_path = [];
      let path = pathTo.slice(0);
      let ii = path.splice(0, 1)[0];
      let curr = this.toc[ii];
      while (path.length > 0) {
        res_path.push({ ii, t: curr.resoure_type });
        if (curr.resource_type !== null || curr.id in this.collapsedSections) {
          return false;
        }
        ii = path.splice(0, 1)[0];
        curr = curr.children[ii];
      }
      return true;
    },
    promptForDelete: function({ id }) {
      return id in this.needsDeleteConfirmation;
    },
    markForDeletion: function({ id }) {
      Vue.set(this.needsDeleteConfirmation, id, true);
    },
    cancelDeletion: function({ id }) {
      Vue.delete(this.needsDeleteConfirmation, id);
    },
    confirmDeletion: function({ id }) {
      this.deleteNode({ casebook: this.casebook, targetId: id });
    },
    moveSubsection: function({ id }, { pathTo }) {
      this.moveNode({ casebook: this.casebook, targetId: id, pathTo });
    },
    isCollapsed: function({ id }) {
      return id in this.collapsedSections;
    },
    toggleSectionExpanded: function({ id }) {
      if (id in this.collapsedSections) {
        Vue.delete(this.collapsedSections, id);
      } else {
        Vue.set(this.collapsedSections, id, true);
      }
    }
  },
  props: ["rootId", "casebook", "editing"],
  created: function() {
    this.fetch({ casebook: this.casebook, subsection: this.rootId });
  }
};
</script>

<style lang="scss">
@import "../styles/vars-and-mixins";

#table-of-contents {
  ol {
    counter-reset: item;
  }
  li {
    counter-increment: item;
    display: block;
  }
  .nestable-item {
    position: relative;
    .actions {
      position: absolute;
      top: -6px;
      right: 0;
      height: 100%;
      margin-top: 6px;
      display: flex;
      flex-direction: column;
      align-content: center;
      justify-content: center;
    }
  }
  .action-confirmation {
    display: flex;
    flex-direction: row;
    justify-content: space-between;
    padding-right: 10px;
    button {
      width: unset;
      height: unset;
      color: unset;
      background-color: unset;
      display: unset;
      margin: unset;
      background-position: unset;
      background-repeat: unset;
      background-size: unset;
      font-weight: 400;
      margin: 2px;
      padding: 6px 16px;
    }
    .action-confirm-delete {
      background-color: $light-blue;
      color: $white;
    }
    .action-cancel-delete {
      background-color: $white;
      color: $black;
    }
  }
  li.nestable-item.is-dragging {
    border: 4px dashed grey;
    border-radius: 8px;
    margin-top: 8px;
    margin-bottom: 8px;
    .listing {
      margin-top: 0px;
      &.section:hover {
        background-color: $black;
        .section-number,
        .section-title {
          color: $white;
        }
      }
      &.resource:hover {
        background-color: $white;
        .resource-case,
        .resource-date,
        .section-number,
        .section-title {
          color: $black;
        }
      }
    }
  }
  .listing-wrapper.delete-confirm .listing {
    padding-right: 168px;
  }
  .listing {
    display: block;
    width: 100%;
    padding: 12px 16px;
    padding-right: 42px;
    margin-top: 6px;
    border: 1px solid $black;

    &.section {
      display: flex;
      flex-direction: column;
      align-items: left;
      background-color: $black;

      @media (max-width: $screen-xs) {
        flex-direction: row;
      }

      .section-title {
        display: inline;
        font-weight: $medium;
      }
      .section-number,
      .section-title {
        color: $white;
        margin-right: 10px;
      }
    }
    &.resource {
      background-color: $white;
      display: grid;
      grid-template-columns: auto 1fr 15%;

      @media (max-width: $screen-xs) {
        .resource-container {
          margin: 0 9px;
        }
      }

      .section-title {
        display: inline;
      }

      .case-section-title {
        margin-bottom: 4px;
      }

      .section-number,
      .section-title {
        color: $black;
      }

      .case-metadata-container {
        display: flex;
        align-items: center;

        @media (max-width: $screen-xxs) {
          flex-direction: column;
          align-items: flex-start;
        }

        .resource-case:empty {
          display: none;
        }

        .resource-case {
          margin-right: 9px;
        }
      }

      .resource-type-container {
        display: flex;
        align-items: center;
        justify-content: flex-end;

        @media (max-width: $screen-xs) {
          margin-right: -4px;

          .resource-type {
            padding: 2px 7px;
          }
        }
      }
    }
    &.empty {
      border: 1px dashed $gray;
      text-align: center;
      color: $dark-gray;
      background: transparent;
      padding: 60px;
    }
    &.section:hover,
    &.section:focus,
    &.resource:hover,
    &.resource:focus {
      background-color: $light-blue;
      border-color: $light-blue;
      * {
        color: $white;
        border-color: $white;
      }
    }
    @media (max-width: $screen-xs) {
      &.section,
      &.resource {
        div {
          margin: 4px 0;
          padding-left: 0;
          text-align: left;
        }
      }
    }
    @media (min-width: $screen-xs) {
      &.section {
        flex-direction: row;
        align-items: center;
      }
    }

    .section-number:before {
      content: counters(item, ".") " ";
      font-size: 12px;
      display: flex;
      align-items: center;
      margin-right: 10px;
    }
    .section-title {
      @include sans-serif($bold, 14px, 14px);
      display: inline-block;
    }
    .resource-type,
    .resource-case,
    .resource-date {
      @include sans-serif($light, 14px, 14px);
      display: inline-block;

      text-align: left;
      color: $black;
    }

    .resource-type {
      border: 1px solid $light-blue;
      color: $light-blue;
      display: flex;
      justify-content: center;
      align-items: center;
      font-size: 12px;
      font-weight: bold;
      height: 20px;
      width: 72px;
    }
  }
  &.confirm-delete {
    margin-right: 160px;
  }
  ol.nestable-list.nestable-group {
    padding-left: 0px;
  }
  .nestable-list {
    .nestable-list {
      border-left: 8px solid $light-blue;
      padding-left: 16px;
    }
  }
  div.editable .nestable-list .nestable-list {
    border-left: 8px solid $yellow;
    padding-left: 16px;
  }
  .nestable-drag-layer {
    opacity: 0.7;
    position: fixed;
    top: 0;
    left: 0;
    z-index: 100;
    pointer-events: none;
    .listing {
      .section-number:before {
        content: "-";
      }
    }
  }
}
</style>
