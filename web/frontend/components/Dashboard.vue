<template>
  <div>
    <Modal v-if="finalizingGroup" @close="finalizingGroup = false">
      <template slot="title">Group Casebooks</template>
      <template slot="body">
        <form @submit.prevent.stop="createGroup" class="form-group">
          <div>
            <div v-if="selectedCoAuthors.length > 0">
              The following co-authors will also see this group: 
              <span>{{selectedCoAuthors}}</span>
            </div>
            <label for="newGroupTitle">
              Title
            </label>
            <input name="newGroupTitle" class="form-control" type="text" v-model="newGroupTitle" autofocus>
            <div class="invalid-feedback" v-if="takenTitle">
              This title is in use by you or one of your co-authors already.
            </div>
          </div>
          <br>
          <div>            
            <label for="current">
              Current Edition
            </label>
            <select name="current" v-model="newGroupCurrent" class="form-control">
              <option v-for="casebook in selectedCasebooks" v-bind:key="casebook.id" :value="casebook">{{casebook.title}}</option>
            </select>
          </div>
          <div class="advice" v-if="user.public_url">
            The current edition will be available at <span>{{newPublicUrl}}</span>
          </div>
          <div class="advice" v-else>
            Your author URL isn't yet set. To give this casebook a nice public url set it up <a target="_blank" href="/accounts/edit/"> on your profile page</a>.
          </div>
          <br>
          <button class="btn btn-primary full-width" :disabled="takenTitle" type="submit" @submit="createGroup">Group these casebooks</button>
        </form>
      </template>
    </Modal>
    <div v-if="user.active">
      <h2 class="casebooks">My Casebooks</h2>
      <div class="archived-link"><a href="casebooks/archived/">[View Archived Casebooks]</a></div>
      <hr class="owned"/>
    </div>
    <div v-else>
      <h2 class="casebooks">{{ user.name }}'s Casebooks</h2>
      <hr class="owned"/>
    </div>
    <div class="management-links" v-if="user.active && !managingCasebooks"> <a @click="startManagement">Manage Casebooks</a> </div>
    <div class="management-links" v-if="user.active && managingCasebooks">
      <ul>
        <li>
          <a v-bind:class="{'disabled': !canArchive}"
             @click="archiveCasebooks"
             @mouseover="activateHelp(archiveHelp)"
             @mouseleave="deactivateHelp">
            Archive selected
          </a>
        </li>
        <li>
          <a v-bind:class="{'disabled': !canUngroup}"
             @click="unTitle"
             @mouseover="activateHelp(ungroupHelp)"
             @mouseleave="deactivateHelp">
            Ungroup selected
          </a>
        </li>
        <li>
          <a v-bind:class="{'disabled': !canGroup}"
             @click="finalizeGroup"
             @mouseover="activateHelp(groupHelp)"
             @mouseleave="deactivateHelp">
            Group selected
          </a>
        </li>
        <li>
          <a title="Finish managing casebooks" @click="stopManagement">Done</a>
        </li>
      </ul>

      <div class="help-manage" v-html="currentHelp">
      </div>
    </div>

<div class="content-browser">
  <div v-bind:class="managingCasebooks ? 'content-selectable' : 'content-clickable'">
    <casebook :selectable="managingCasebooks" :casebook="casebook" v-model="selectedCasebooks" v-for="casebook in casebooks" v-bind:key="casebook.id"> </casebook>
  </div>
</div>


<div class="title-holder" v-for="title in titles" v-bind:key="title.id">
  <div class="title-divider">
    <span class="title-name">{{ title.name }}</span>
    <span class="title-slug">
      <a :href="titleUrl(title)" v-if="user.public_url"> {{titleUrl(title)}}</a>
      <a href="/accounts/edit/" v-else>Set up your public url </a>
    </span>
  </div>
  <div v-if="user.active && managingCasebooks" class="management-links">
    <ul>
      <li>
        <a
          v-bind:class="{'disabled': !canAddToGroup}"
          @click="addToTitle(title)"
          @mouseover="activateTitleHelp(addToGroupHelp(title), title)"
          @mouseleave="deactivateTitleHelp">
          Add selected to group
        </a>
      </li>
      <li>
        <a v-bind:class="{'disabled': !canSetCurrent(title)}"
           @click="setCurrent(title)"
           @mouseover="activateTitleHelp(setCurrentTitleHelp(title), title)"
           @mouseleave="deactivateTitleHelp">
          Set current edition
        </a>
      </li>
      <li>
        <a @click="deleteTitle(title)">
          Delete group
        </a>
      </li>
    </ul>
    <div class="help-manage" v-html="titleHelp(title)">
    </div>
  </div>

  <div class="content-browser" v-if="title.expanded">
    <div v-bind:class="managingCasebooks ? 'content-selectable' : 'content-clickable'">
      <div class="current-edition">
        <casebook :casebook="title.current" :selectable="managingCasebooks" v-model="selectedCasebooks"> </casebook>
        <div> Current edition </div>
      </div>
      <casebook :casebook="casebook"
                v-for="casebook in outDated(title)"
                v-bind:key="casebook.id"
                :selectable="managingCasebooks"
                v-model="selectedCasebooks">
      </casebook>
    </div>
  </div>
  <div class="content-browser" v-else>
    <div class="current-edition">
      <casebook :casebook="title.current" :selectable="managingCasebooks" v-model="selectedCasebooks"> </casebook>
      <div> Current edition </div>
    </div>

    <div v-if="title.casebooks && title.casebooks.length > 1" class="expand-editions-container">
      <a @click="expandTitle(title)">Show {{ title.casebooks.length -1}} other editions</a>
    </div>
    <div v-else class="expand-editions-container">
      Only one edition.
    </div>
  </div>
</div>
</div>
</template>

<script>
import _ from "lodash";
import Casebook from "./Dashboard/Casebook";
import Axios from "../config/axios";
import Vue from "vue";
import Modal from "./Modal";
import urls from "../libs/urls";

export default {
    components: { Casebook, Modal },
    data: () => ({
        finalizingGroup: false,
        newGroupCurrent: {},
        selectedCasebooks: [],
        newGroupTitle:'',
        managingCasebooks: false,
        currentHelp: '&nbsp;',
        currentTitleHelp: '&nbsp;',
        currentTitleHelpId: null,
        casebooks:[],
        titles:[],
        user:{}
    }),
    props: ['casebookList'],
    watch: {
        selectedCasebooks: function(newVal) {
            if (newVal.length >= 1) {
                this.newGroupCurrent = this.defaultCurrent(newVal);
            }
        }
    },
    computed: {
        selectedCoAuthors: function() {
          return _.sortBy(
            _.filter(
              _.uniq(
                _.map(
                  _.flatMap(this.selectedCasebooks, 'authors'),
                  'attribution')),
              attribution => attribution !== this.user.name)
          ).join(", ");
        },
        takenTitle: function() {
            return this.allTitleUrls.includes(this.slugifyNewTitle);
        },
        allTitleUrls: function() {
            return _.uniq(_.flatMap(_.flatMap(this.allCasebooks, 'authors'), 'titles'));
        },
        canArchive: function() {
            return _.every(this.selectedCasebooks, 'can_archive');
        },
        archiveHelp: function() {
            return this.canArchive ? "Archived casebooks will not be visible to others" : "You must unpublish casebooks before you can archive them";
        },
        canGroup: function() {
            const freeIDs = _.map(this.casebooks, 'id');
            return this.selectedCasebooks.length > 0 && _.every(this.selectedCasebooks, ({id, is_public}) => is_public && freeIDs.includes(id));
        },
        groupHelp: function() {
            return this.canGroup ? "Collect editions of the same casebook, and promote the ." : "Only published casebooks can be grouped. Casebooks may only belong to one group.";
        },
        canUngroup: function() {
            const freeIDs = _.map(this.casebooks, 'id');
            return this.selectedCasebooks.length > 0 && _.find(this.selectedCasebooks, ({id}) => !freeIDs.includes(id));
        },
        ungroupHelp: function() {
            return this.canUngroup ? "Remove selected casebooks from groups" : "None of the selected casebooks belong to a group";
        },
        uniqueSelection: function() {
            return this.selectedCasebooks.length === 1;
        },
        hasTitledCasebooks: function () {
            return this.allCasebooks.titled.length > 0;
        },
        newPublicUrl: function () {
            return `${window.location.origin}/author/${this.user.public_url}/${this.slugifyNewTitle}`;
        },
        slugifyNewTitle: function() {
            const toStrip = /[^a-zA-Z0-9 _-]/g;
            let temp = this.newGroupTitle.toLowerCase().replace(toStrip,'').replace(/ /g,'-');
            return temp.length === 0 ? '***' : temp;
        },
        titledCasebookSelected: function() {
            return !_.isEmpty(_.intersectionBy(_.flatMap(this.titles, 'casebooks'), 'id'), this.selectedCasebooks);
        },
        allCasebooks: function() {
            return this.casebooks.concat(_.flatMap(this.titles, 'casebooks'));
        }
    },
    methods: {
        activateHelp: function (currentHelp) {
            this.currentHelp = currentHelp;
        },
        deactivateHelp: function() {
            this.currentHelp = '&nbsp;';
        },
        activateTitleHelp: function(currentHelp, title) {
            this.currentTitleHelp = currentHelp;
            this.currentTitleHelpID = title.id;
        },
        deactivateTitleHelp: function() {
            this.currentTitleHelp = '&nbsp;';
            this.currentTitleHelpID = null;
        },
        titleHelp: function(title) {
            let helpText = this.currentTitleHelp;
            if (title.id === this.currentTitleHelpID) {
                return helpText;
            }
            return '&nbsp;';
        },
        canSetCurrent: function(title) {
            return this.uniqueSelection && this.selectionWithinTitle(title);
        },
        setCurrentTitleHelp: function(title) {
            return this.canSetCurrent(title) ? "Sets the current edition to the selected casebook" : "Please specify a unique edition to make current";
        },
        canAddToGroup: function(title) {
            return this.canGroup;
        },
        addToGroupHelp: function(title) {
            return this.canAddToGroup(title) ? "Add selected casebooks to this group" : "Only public casebooks that do not belong to another group can be added to this group";
        },        
        resetManagement: function() {
            this.finalizingGroup = false;
            this.newGroupCurrent =  {};
            this.selectedCasebooks =  [];
            this.newGroupTitle = '';
            for(const title of this.titles) {
                Vue.set(title, 'expanded', true);
            }
        },
        titleUrl: function(title) {
            return `${window.location.origin}/author/${this.user.public_url}/${title.public_url}/`
        },
        isSelected: function(casebook) {
            return this.selectedCasebooks.filter(x => x.id === casebook.id).length === 1;
        },
        createGroup: function() {
            if (this.takenTitle) return;
            const url = '/api/titles/';
            const data = {
                'name': this.newGroupTitle,
                'public_url': this.slugifyNewTitle,
                'current': this.newGroupCurrent.id,
                'casebooks': this.selectedCasebooks
            };
            Axios.post(url, data).then(
                this.handleTitlePostResponse,
                this.handleTitleCreateErrors
            );
            this.resetManagement();
        },
        handleTitlePostResponse: function(response) {
            let newTitle = response.data;
            newTitle.expanded = true;
            const targets = newTitle.casebooks;
            this.removeCasebooks(targets);
            this.titles.push(newTitle);
        },
        handleTitleCreateErrors: function() {
            console.error(arguments);
        },
        startManagement: function(){
            this.managingCasebooks = true;
            this.selectedCasebooks = [];
            this.newGroupTitle = '';
            for (const title of this.titles) {
                this.expandTitle(title);
            }
        },
        expandTitle: function(title) {
            Vue.set(title, 'expanded', true);
        },
        archiveCasebooks: function() {
            const self = this;
            if (! this.canArchive) return;
            for(const casebook of this.selectedCasebooks) {
                let formData = new FormData();
                formData.append("transition_to", "Archived");
                const url = urls.url('casebook_settings')({casebookId: casebook.id});
                Axios.post(url, formData).then(
                    self.handleArchiveResponse(casebook),
                    console.error
                );
            }
        },
        handleArchiveResponse: function(casebook) {
            const self = this;
            return function() {
                self.removeCasebooks([casebook])
            };
        },
        stopManagement: function() {
            this.managingCasebooks = false;
            this.selectedCasebooks = [];
        },
        finalizeGroup: function() {
            if (!this.canGroup) return;
            let potentialTitles = _.sortBy(this.selectedCasebooks.map(({title}) => title));
            let longestPrefix = _.takeWhile(_.zip(_.map(_.first(potentialTitles)), _.map(_.last(potentialTitles))).map(([a,b]) => a === b ? a : false)).join('').trim();
            this.newGroupTitle = longestPrefix;
            this.finalizingGroup = true;
        },
        deleteTitle: function(title) {
            const url = `/api/titles/${title.id}`;
            Axios.delete(url).then(this.handleTitleDeleteResponse(title.id), this.handleTitleDeleteError);
        },
        addToTitle: function(title) {
            let data = _.cloneDeep(title)
            data.casebooks = title.casebooks.concat(_.difference(this.selectedCasebooks, title.casebooks));
            this.updateTitle(data);
        },
        selectionWithinTitle: function(title) {
            const ids = _.map(title.casebooks, 'id');
            return _.every(this.selectedCasebooks, ({id}) => ids.includes(id));
        },
        setCurrent: function(title) {
            if (!this.canSetCurrent) return;
            title.current = this.selectedCasebooks[0];
            this.updateTitle(title);
        },
        updateTitle: function(title) {
            const url = `/api/titles/${title.id}`;
            Axios.put(url, title).then(this.handleTitleUpdateResponse, this.handleTitleUpdateError);
        },
        unTitle: function() {
            if (!this.canUngroup) return;
            let titlesToUpdate = this.titles.filter(title => !_.isEmpty(_.intersectionBy(title.casebooks, this.selectedCasebooks, 'id')));
            let emptyTitles = titlesToUpdate.filter(title => _.isEmpty(_.differenceBy(title.casebooks, this.selectedCasebooks, 'id')));
            let truncatedTitles = _.difference(titlesToUpdate, emptyTitles);
            for (const empty of emptyTitles) {
                this.deleteTitle(empty);
            }
            const selectedIDs = _.map(this.selectedCasebooks, 'id');
            for (const title of truncatedTitles) {
                let data = _.cloneDeep(title);
                data.casebooks = _.remove(data.casebooks, ({id}) => selectedIDs.includes(id));
                if (!data.current || !data.casebooks.includes(data.current)) {
                    data.current = this.defaultCurrent(data.casebooks);
                }
                this.updateTitle(data);
            }
        },
        defaultCurrent: function(casebooks) {
            return _.last(_.sortBy(_.filter(casebooks, 'is_public'), 'updated_at'));
        },
        handleTitleDeleteResponse: function(targetId) {
            const self = this;
            return function(response){
                let freedTitle = _.findIndex(self.titles, ({id}) => id === targetId);
                if (freedTitle !== -1) {
                    for(const cb of self.titles[freedTitle].casebooks) {
                        self.casebooks.push(cb);
                    }
                    self.titles.splice(freedTitle);
                }
            };
        },
        handleTitleDeleteError: function(response) {
            console.error(response);
        },
        removeCasebooks: function(casebooks) {
            const ids = _.map(casebooks, 'id');
            const matcher = ({id}) => ids.includes(id);
            function removeFromArray(casebookArray) {
                let index = _.findIndex(casebookArray, matcher);
                while(index !== -1) {
                    casebookArray.splice(index,1);
                    index = _.findIndex(casebookArray, matcher, index);
                }
            }
            console.log("Looking in Casebooks");
            removeFromArray(this.casebooks);
            for (const titleCasebooks of this.titles) {
                console.log(`Looking in Title(${titleCasebooks.id})`)
                removeFromArray(titleCasebooks.casebooks);
            }
        },
        handleTitleUpdateResponse: function(response) {
            const title = response.data;
            const oldTitle = _.find(this.titles, ({id}) => id === title.id);
            if (oldTitle) {
                let freedCasebooks = _.difference(oldTitle.casebooks, title.casebooks);
                for (const casebook of freedCasebooks) {
                    this.casebooks.push(casebook);
                }
            }
            this.removeCasebooks(title.casebooks);
            let index = _.findIndex(this.titles, ({id}) => title.id);
            if (index !== -1) {
                Vue.set(this.titles, index, title);
            } else {
                this.titles.push(title);
            }
            this.resetManagement();
        },
        handleTitleUpdateError: function(response) {
            console.error(response);
        },
        outDated: function(title) {
            return _.filter(title.casebooks, ({id}) => id !== title.current.id);
        }
    },
    mounted: function() {
        this.casebooks = this.casebookList.casebooks;
        this.titles = this.casebookList.titles;
        this.user = this.casebookList.user;
    }
  };
</script>

<style lang="scss">
@use "sass:color";
@import "variables";


.casebook-select-list {
    display: flex;
    flex-direction: row;
    padding-left:0;
    overflow-x:scroll;
    
    .untitled {
        width: 100%;
    }    
    
    .new-group-choices {
        list-style: none;
        display: flex;
        flex-direction: column;
        flex-wrap: wrap;
        padding-left:0;
        overflow-x:scroll;
        li {
            overflow-x:scroll;
            
            &.header {
                page-break-before: always;
                break-before: always;
                padding-left: 0px;
                border-bottom: 1px solid grey;
            }
        }
    }
}

.break {
    page-break-before: always;
    flex-basis: 100%;
    width: 0;
}

.new-title {
    display: flex;
    flex-direction: row;
    .advice {
        align-self: flex-end;
        margin-left: 16px;
        margin-bottom: 16px;
    }
}

.expand-editions-container {
    flex-grow: 1;
    align-self: center;
    text-align: center;
}

.form-grid {
    display:grid;
    grid-template-columns: auto auto;
    margin-top: 16px;
    .full-width {
        margin-top:8px;
        grid-column-start: 1;
        grid-column-end: 3;
    }
}

.title-holder {
    margin-top: 16px;
    margin-bottom: 16px;
}


.content-selectable {
    display:flex;
    flex-wrap:wrap;
}

.content-clickable {
    display:flex;
    flex-wrap: wrap;
    .padded {
        flex-direction: column;
        padding-bottom: 16px;
    }
}

.management-links {
    float:right;
    ul {
        list-style: none;
        display: flex;
        flex-direction: row;
        justify-content: flex-end;
        li a {
            cursor: pointer;
            padding-left: 4px;
            padding-right: 4px;
            &.disabled {
                color: grey;
                cursor: not-allowed;
            }
        }
        li:not(:last-child):after {
            content: "|";
        }
    }
}
.title-divider + .management-links {
    margin-top: -2rem;
}

.current-edition {
    display: flex;
    flex-direction: column;
    align-items: center;
}

.invalid-feedback {
    color:$red;
}

.help-manage {
    text-align: end;
}
</style>
