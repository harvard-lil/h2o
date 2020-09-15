<template>

<div class="collaborator-list">
  <form class="form-control-group" @submit.stop.prevent="1">
      <table>
        <tr>
          <th class="left-adjusted"></th>
          <th>Name</th>
          <th>Email</th>
          <th class="centered">Has Attribution</th>
          <th class="centered">Can Edit</th>
          <th class="centered">Remove</th>
        </tr>
        <tr v-for="collab in modifiedCollaborators" v-bind:key="collab.id" v-bind:class="[collab.modified ? 'modified' : '']">
          <td class="left-adjusted"><span v-if="collab.modified" title="Unsaved Changes" class="modified-alert">!</span></td>
          <td>{{collab.user.attribution}}</td>
          <td>{{collab.user.email_address}}</td>
          <td class="centered"><input type="checkbox" v-model="collab.has_attribution" /></td>
          <td class="centered"><input type="checkbox" v-model="collab.can_edit" :disabled="oneActiveEditor && collab.can_edit" :title="oneActiveEditor && collab.can_edit ? 'At least one author must be able to edit this casebook' : ''"/></td>
          <td class="centered"><input type="checkbox" v-model="collab.delete" :disabled="oneActiveUser && !collab.delete" :title="oneActiveUser && !collab.delete ? 'This casebook must have at least one author' : ''"/></td>
        </tr>
      </table>
      <label>
        Add Collaborator
        <autocomplete :search="search"
                      base-class="user-search"
                      placeholder="Search by email address"
                      :get-result-value="userEmail"
                      @submit="addCollaborator"
                      @update="updateCollaborator"
                      >
          <template
            #default="{
                      rootProps,
                      inputProps,
                      inputListeners,
                      resultListProps,
                      resultListListeners,
                      results,
                      resultProps
                      }"
            >
            <div v-bind="rootProps">
              <input
                aria-label="Search for a user by email address"
                ref="newUserEmail"
                v-on="inputListeners"
                class="form-control autocomplete-input force-min-width"
                role="combobox"
                autocomplete="off"
                autocapitalize="off"
                autocorrect="off"
                spellcheck="false"
                aria-autocomplete="list"
                aria-haspopup="listbox"
                v-bind:aria-owns="inputProps['aria-owns']"
                v-bind:aria-expanded="inputProps['aria-expanded']"
                v-bind:aria-activedescendant="inputProps['aria-activedescendant']"
                />
              <ul v-bind="resultListProps"
                  v-on="resultListListeners"
                  class="autocomplete-results-list"
                  role="listbox"
                  >
                <li
                  role="option"
                  v-for="(result, index) in results"
                  :key="resultProps[index].id"
                  v-bind="resultProps[index]"
                  v-bind:class="[resultProps[index]['aria-selected'] === 'true' ? 'focused' : '']"
                  v-bind:aria-selected="resultProps[index]['aria-selected']"
                  >
                  {{ result.attribution }} ({{result.email_address}})
                </li>
              </ul>
            </div>
          </template>
      </autocomplete>
      </label>
      <input type="submit" class="btn btn-primary inline-btn" name="addCollabButton" value="Add" @click.stop.prevent="addCollaborator(null)"/>
  </form>
  <br />
  <form @submit.stop.prevent="submitModifications" class="form-control-group">
    <div class="form-control-group">
      <input type="submit"
             class="btn btn-primary"
             name="Submit"
             :value="modificationCount === 0 ? 'No changes to save' : 'Save changes to collaborators'"
             :disabled="modificationCount == 0"
             :title="modificationCount === 0 ? 'No changes to save' : 'Save changes to collaborators'"/>
    </div>
  </form>
</div>
</template>

<script>
import _ from "lodash";
import Autocomplete from '@trevoreyre/autocomplete-vue';
import Axios from "../config/axios";
import urls from "../libs/urls";
const userSearchUrl = urls.url('user_search')({});
const updateCollaboratorsUrl = urls.url('api_collaborators');

export default {
    components: {Autocomplete},
    props: ["initialCollaborators", "casebook"],
    data: () => ({ allCollaborators: [],
                   savedCollaborators: [],
                   searchMap: {},
                   userEmailToAdd: {}
                }),
    methods: {
        search:function(str) {
            if(str.length < 2) return [];
            const data = {email_address: str};
            return Axios.get(userSearchUrl,{params: data}).then(r => r.data);
        },
        userEmail: function(res) {
            return res.email_address;
        },
        addCollaborator: function(choice) {
            const emailRegex = /[^@]*@[^.]*[.].*/;
            let nue = this.$refs.newUserEmail.value;
            let user = choice || {email_address: nue};
            let existingEmails = this.allCollaborators.map(x => x.user.email_address);
            if (!emailRegex.exec(user.email_address)) { return; }
            if (existingEmails.indexOf(user.email_address) !== -1) {
                return;
            }
            const newCollab = {has_attribution: true, can_edit: true, casebook: this.casebook, user, id: user.email_address};
            this.allCollaborators.push(newCollab);
            this.$refs.newUserEmail.value = '';
        },
        updateCollaborator: function(a,b) {
        },
        submitModifications: function() {
            const deletedCollaborators = this.modifiedCollaborators.filter(x => x.delete && _.isInteger(x.id)).map(x => x.id);
            const updatedCollaborators = this.modifiedCollaborators.filter(x => x.modified && !x.delete)
                                             .map(x => _.omit(x,_.isInteger(x.id) ? ['delete', 'modified'] : ['delete', 'modified', 'id']));
            const url = updateCollaboratorsUrl({casebookId: this.casebook});
            if (deletedCollaborators.length > 0) {
                Axios.post(url, deletedCollaborators, {headers: {"X-HTTP-Method-Override": "DELETE"}})
                     .then((response) => {
                           if (updatedCollaborators.length > 0) {
                                 Axios.post(url, updatedCollaborators).then(this.saveSuccess, this.saveFailure);
                           } else {
                               this.saveSuccess(response);
                           }
                     }, this.saveFailure);

            } else {
                Axios.post(url, updatedCollaborators).then(this.saveSuccess, this.saveFailure);
            }
        },
        saveSuccess: function(resp) {
            this.savedCollaborators = _.cloneDeep(resp.data);
            this.allCollaborators = _.cloneDeep(resp.data);
        },
        saveFailure: function(e) {
            console.error(e);
        }
    },
    computed: {
        modificationCount: function() {
            return _.filter(this.modifiedCollaborators, (x) => x.modified).length;
        },
        oneActiveUser: function() {
            return _.filter(this.modifiedCollaborators, x => !x.delete).length === 1;
        },
        oneActiveEditor: function() {
            return _.filter(this.modifiedCollaborators, x => !x.delete && x.can_edit).length === 1;
        },
        modifiedCollaborators: {
            set: function(val) {
                this.allCollaborators = val;
            },
            get: function() {
                function eq(a,b) {
                    return ( a && b && !a.delete &&
                       _.every(['can_edit', 'casebook', 'has_attribution', 'id'],k => a[k] == b[k]) &&
                       _.every(['affiliation', 'attribution', 'email_address','id'],k => a.user[k] == b.user[k]));
                }
                _.forEach(this.allCollaborators, (m, ii) => {
                    m.modified = !eq(m, _.get(this.savedCollaborators, ii));
                });
                return this.allCollaborators;
            }
        }
    },
    mounted: function() {
        this.savedCollaborators = _.cloneDeep(this.initialCollaborators);
        this.allCollaborators = _.cloneDeep(this.initialCollaborators);
    }
};
</script>

<style lang="scss" scoped>
  @import "variables.scss";

.collaborator-list {
    padding: 4px;
    table {
        margin-top: 2rem;
        margin-bottom: 2rem;
        width: 100%;
        tr {
            .left-adjusted {
                width: 2rem;
                margin-left: -3rem;
                position: fixed;
                margin-top: -0.25rem;
            }
            td,th {
                padding:6px;
                &.centered {
                    text-align:center;
                }
            }
            &.modified {
                span.modified-alert {
                    background-color: $yellow;
                    border-radius: 2rem; 
                    font-weight: 900;
                    font-size: large;
                    padding: 0.5rem 1rem;
                    cursor: help;
                    vertical-align: baseline;
                    
                 }
            }
        }
    }
}

  .inline-btn {
    height: 52px;
    vertical-align: baseline;
    margin-top: -4px;
    padding-top: 16px;
  }
.form-control.force-min-width {
    min-width: 600px;
}

.user-search-result-list {
    list-style: none;
    border: 1px solid black;
    border-bottom-left-radius: 8px;
    border-bottom-right-radius: 8px;
    border-top: 0px solid transparent;
    background-color: white;
    padding-left: 0px;
    li {
        padding: 8px;
        &:hover {
            background-color: light-blue;
        }
        &.focused {
            padding: 4px;
            border: 4px solid #66afe9;;
        }
        &:not(:last-child) {
            border-bottom: 1px solid grey;
            &.focused {
                border-bottom: 4px solid #66afe9;
            }
        }
    }
}

</style>
