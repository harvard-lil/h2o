<% include Rails.application.routes.url_helpers %>
<% include ActionView::Helpers::JavaScriptHelper %>

import {html, raw} from 'es6-string-html-template';
import delegate from 'delegate';
import Component from 'lib/ui/component';
import AxiosConfig from 'axios';
import {post} from 'lib/requests';
import {get_csrf_token} from 'lib/helpers';

// The CAP api search functions use regular Axios, rather than the customized
// stuff available in lib/requests, which sets location on parent pages, etc.
// So.... CSRF handling stuff here too....
const csrf_token = get_csrf_token();
let headers = csrf_token ? {'X-CSRF-Token': csrf_token} : {};
let Axios = AxiosConfig.create({headers: headers});

delegate(document, '.action.add-resource, .listing .add-resource', 'click', showResourceModal);

let modal = null;

function showResourceModal (e) {
  e.preventDefault();
  modal = new AddResourceModal;
}

class AddResourceModal extends Component {
  constructor () {
    super({
      id: 'add-resource-modal',
      events: {
        'click #add-resource-modal': (e) => { if (e.target.id === 'add-resource-modal') this.destroy()},
        'click .close': (e) => { this.destroy() },
        'click .search-tab': (e) => {
          this.activeType = e.target.dataset.type;
          this.render();
        },

        'submit form.new-text': (e) => {
          e.preventDefault();
          e.stopPropagation();
          post('<%= sections_path('$CASEBOOK_ID') %>'.replace('$CASEBOOK_ID', this.casebookId()), {
            resource_id: e.delegateTarget.dataset.resultId,
            parent: this.sectionId(),
            text: {
              content: e.target.querySelector('textarea[name=content]').value,
              title: e.target.querySelector('input[name=title]').value,
            }
          }, {modal: this});
        },
        'submit form.new-link': (e) => {
          e.preventDefault();
          e.stopPropagation();
          post('<%= sections_path('$CASEBOOK_ID') %>'.replace('$CASEBOOK_ID', this.casebookId()), {
            resource_id: e.delegateTarget.dataset.resultId,
            parent: this.sectionId(),
            link: {
              url: e.target.querySelector('input[name=url]').value
            }
          }, {modal: this});
        },
        'submit form.case-search, click .pagination a': (e) => {
          e.preventDefault();
          e.stopPropagation();
          let request;
          if (e.target.href) {
            request = Axios.get(e.target.href);
          } else {
            this.q = e.target.querySelector('input[name=q]').value;
            request = Axios.get('<%= j search_path %>', {
              params: {
                partial: true,
                type: 'cases',
                q: this.q
              }
            });
          }
          request.then((res) => {
            this.caseResultHtml = res.data;
            this.render();
          })
        },
        'click .results-list > a': (e) => {
          e.stopPropagation();
          e.preventDefault();

          const add = id => {
            post('<%= sections_path('$CASEBOOK_ID') %>'.replace('$CASEBOOK_ID', this.casebookId()),
                 {resource_id: id,
                  parent: this.sectionId()},
                 {modal: this})
          };

          if (e.delegateTarget.dataset.resultType == 'capapi/case') {
            Axios
              .post('/cases/from_capapi', {id: e.delegateTarget.dataset.resultId})
              .then(response => { add(response.data.id) });
          } else {
            add(e.delegateTarget.dataset.resultId);
          }
        }
      }
    });
    document.body.appendChild(this.el);
    document.body.classList.add('modal-open');
    this.activeType = 'case';
    this.render();
  }

  render () {
    let instance = CKEDITOR.instances['add_resource_text_content']
    if (instance) { instance.destroy(true); }
    super.render();
    if (this.activeType === 'text') {
      CKEDITOR.replace('add_resource_text_content', {toolbar: 'mini'});
    }
  }

  casebookId () {
    return document.querySelector('header.casebook').dataset.casebookId;
  }
  sectionId () {
    return document.querySelector('header.casebook').dataset.sectionId;
  }

  destroy () {
    super.destroy();
    document.body.classList.remove('modal-open');
    modal = null;
  }

  template () {
    return html`<div class="modal fade in" id="add-resource-modal" style="display: block">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <button type="button" class="close"><span>&times;</span></button>
            <h4 class="modal-title"><%= I18n.t 'content.add-resource-modal.title' %></h4>
          </div>
          <div class="modal-body">
            <div class="search-tabs">
              <div class="search-tab ${this.activeType === 'case' ? 'active' : ''}" data-type="case">
                <%= I18n.t 'content.add-resource-modal.tabs.case' %>
              </div>
              <div class="search-tab ${this.activeType === 'text' ? 'active' : ''}" data-type="text">
                <%= I18n.t 'content.add-resource-modal.tabs.text' %>
              </div>
              <div class="search-tab ${this.activeType === 'link' ? 'active' : ''}" data-type="link">
                <%= I18n.t 'content.add-resource-modal.tabs.link' %>
              </div>
            </div>
              ${this.addResourceBody()}
            </div>
          </div>
        </div>
      </div>
    </div>`
  }

  addResourceBody () {
    if (this.activeType === 'case') {
      return html`<div class="add-resource-body">
        <form class="case-search">
          <input class="form-control" name="q" type="text" value="${this.q}" placeholder="<%= I18n.t 'content.add-resource-modal.case-search.query-placeholder' %>" />
          <input class="search-button" type="submit" value="<%= I18n.t 'content.add-resource-modal.case-search.search-button' %>" />
        </form>
        ${raw(this.caseResultHtml || '')}
      </div>`;
    } else if (this.activeType == 'text') {
      return html`<div class="add-resource-body">
        <form class="new-text">
          <div class="form-group">
            <label class="title">
              <%= I18n.t 'content.add-resource-modal.new-text.title-label' %>
              <input class="form-control" name="title" type="text" />
            </label>
          </div>
          <div class="form-group">
            <label>
              <%= I18n.t 'content.add-resource-modal.new-text.content-label' %>
              <textarea id="add_resource_text_content" class="form-control" name="content" placeholder="<%= I18n.t 'content.add-resource-modal.new-text.content-placeholder' %>"></textarea>
            </label>
          </div>
          <input class="save-button" type="submit" value="Save text" />
        </form>
      </div>`;
    } else if (this.activeType == 'link') {
      return html`<div class="add-resource-body">
        <h3><%= I18n.t 'content.add-resource-modal.new-link.header' %></h3>
        <h4><%= I18n.t 'content.add-resource-modal.new-link.examples' %></h4>
        <form class="new-link">
          <input class="form-control" name="url" type="text" placeholder="<%= I18n.t 'content.add-resource-modal.new-link.url-placeholder' %>" />
          <input class="search-button" type="submit" value="<%= I18n.t 'content.add-resource-modal.new-link.save-button' %>" />
        </form>
      </div>`;
    }
  }
}
