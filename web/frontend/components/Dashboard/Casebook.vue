<template>
  <div v-bind:class="['padded', selected ? 'selected' : '']">

    <div class="select-label-container">
        <label v-if="selectable">
          Select
          <input type="checkbox" class="casebook-check" :value="casebook" v-model="selectionIndirection">
        </label>
    </div>

    <component
      v-bind:is="clickAction"
      class="wrapper"
      :href="outerUrl"
      @click="selectBook">

      <div class="casebook-container" >
        <div v-bind:class="{'content-page': true,
                            'archived': casebook.is_archived,
                            'public': casebook.is_public ,
                            'draft': !(casebook.is_public || casebook.is_archived)}">
          <div class="state">{{ displayState }}</div>
          <div class="cover-image-container" v-if="casebook.cover_image" >
              <img class="cover-image" v-bind:src="casebook.cover_image" title="cover"/>
          </div>

          <div v-else class="casebook-info">
            <div class="title">{{ casebook.title }}</div>
            <div class="subtitle">{{ casebook.subtitle }}</div>

            <div class="author-info">
              <div class="owner">
                <ul>
                  <li v-for="author in attributed(casebook.authors)" v-bind:key="author.id" v-bind:class="author.verified_professor ? 'verified-prof' : ''">
                    {{ author.attribution }}
                  </li>
                </ul>
              </div>
            </div>
          </div>

          <component v-bind:is="clickAction" class="wrapper" :href="casebook.draft_url" v-if="casebook.has_draft && casebook.user_editable">
            <div class="unpublished-changes">
              <span class="exclamation">!</span>
              <span class="description">This casebook has unpublished changes.</span>
            </div>
          </component>
          
        </div>

        <div class="casebook-sub-info">
          <div class="info-title">{{ casebook.title }}</div>
          <div class="info-author-info">
              <p v-for="author in attributed(casebook.authors)" v-bind:key="author.id">
                {{ author.attribution }}
              </p>
          </div>
            <button type="button" class="view-book-button" tabindex="-1">
              View
            </button>
        </div>
      </div>

    </component>

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
        attributed: function(authors) {
            return _.filter(authors, 'has_attribution');
        },
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
    margin-left:20px;
    padding-left:10px;
    padding-top:8px;
    flex-direction: column;

    .select-label-container{
      height: 20px;
      text-align: right;
    }
    label{
      margin-right: 20px;
      font-size: 15px;
      padding-bottom:12px;
    }
    .casebook-check{
      margin-left: 10px;
      width: 1.5rem;
      height: 1.5rem;
      border: 0;
      outline: 0;
      flex-grow: 0;
      border-radius: 50%;
      background-color: #FFFFFF;
    }
    &.selected {
      background-color: rgba($light-blue,0.6);
      outline: 2px solid $light-gray;
      border-radius: 20px;
      margin-bottom:20px;
    }
    .cover-image{
      width:210px;
      height:320px;
    }
  }

  .padded :focus{
    outline: none;
    box-shadow:none;
    .content-page{
      box-shadow: 0 3px 40px rgb(0 0 0 / 0.3);
    }
  }



</style>
