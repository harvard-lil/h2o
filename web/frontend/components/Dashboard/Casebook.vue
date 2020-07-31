<template>
  <div v-bind:class="['padded', selected ? 'selected' : '']">
    <component
      v-bind:is="clickAction"
      class="wrapper"
      :href="outerUrl"
      @click="selectBook">
      <div v-bind:class="{'content-page': true,
                    'archived': casebook.is_archived,
                    'public': casebook.is_public ,
                    'draft': !(casebook.is_public || casebook.is_archived)}">
        <div class="casebook-info">
          <div class="state">{{ displayState }}</div>
          <div class="title">{{ casebook.title }}</div>
          <div class="subtitle">{{ casebook.subtitle }}</div>
        </div>
  
        <component v-bind:is="clickAction" class="wrapper" :href="casebook.draft_url" v-if="casebook.has_draft && casebook.user_editable">
          <div class="unpublished-changes">
            <span class="exclamation">!</span>
            <span class="description">This casebook has unpublished changes.</span>
          </div>
        </component>
        <div class="author-info">
          <div class="owner">
            <ul>
              <li v-for="author in casebook.authors" v-bind:key="author.id" v-bind:class="author.verified_professor ? 'verified-prof' : ''">
                {{ author.attribution }}
              </li>
            </ul>
          </div>
        </div>
      </div>
    </component>
    <label v-if="selectable">
      Select
      <input type="checkbox" class="casebook-check" :value="casebook" v-model="selectionIndirection">
    </label>
  </div>
</template>

<script>
  import _ from "lodash";

export default {
    props: ['casebook', 'selectable', 'value'],
    computed: {
        selectionIndirection: {
            get() {
                return this.value;
            },
            set(val) {
                this.$emit('input', val);
            }
        },
        clickAction: function() {
            if (this.selectable) {
                return 'div';
            } else {
                return 'a';
            }
        },
        selected: function() {
            return _.find(this.value, ({id}) => id === this.casebook.id);
        },
        outerUrl: function outerUrl() {
            return this.casebook.is_public ? this.casebook.url :
                (this.casebook.is_archived ? this.casebook.settings_url : this.casebook.edit_url);
        },
        displayState: function displayState() {
            if (this.casebook.is_public) {
                return 'Published';
            }
            if (this.casebook.has_draft) {
                return 'with draft';
            }
            if (this.casebook.is_archived) {
                return 'Archived';
            }
            return 'Draft';
        }
    },
    methods: {
        selectBook: function() {
            if (!this.selectable) return;
            this.selectionIndirection = _.find(this.value, this.casebook) ?
                _.difference(this.value, [this.casebook]) :
                _.concat(this.value, [this.casebook]);
        }
    }
};
</script>


<style lang="scss">

  @use "sass:color";
  @import "variables";

  .verified-prof {
  background-image: url('~static/images/ui/verified.png');
  background-position: top 6px right;
  background-repeat: no-repeat;
  background-size: auto;
  }

  .padded {
    display: flex;
    flex-wrap: wrap;
    padding-left:15px;
    padding-top:8px;
    flex-direction: column;
    label {
            margin-bottom: 8px;
            font-weight: 700;
            margin-top: -16px;
            align-self: center;
        }
        &.selected {
            background-color: rgba($light-blue,0.6);
            outline: 2px solid $light-gray;
        }
    }



</style>
