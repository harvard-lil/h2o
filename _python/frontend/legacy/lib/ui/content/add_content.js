import {html, raw} from 'es6-string-html-template';
import delegate from 'delegate';
import Component from 'legacy/lib/ui/component';
import AxiosConfig from 'axios';
import {post} from 'legacy/lib/requests';
import {get_csrf_token} from 'legacy/lib/helpers';

// The CAP api search functions use regular Axios, rather than the customized
// stuff available in lib/requests, which sets location on parent pages, etc.
// So.... CSRF handling stuff here too....
const csrf_token = get_csrf_token();
let headers = csrf_token ? {'X-CSRF-Token': csrf_token} : {};
let Axios = AxiosConfig.create({headers: headers});

delegate(document, '.action.add-resource, .listing .add-resource', 'click', showResourceModal);

let modal;  // eslint-disable-line no-unused-vars

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
        'click .close': () => { this.destroy() },
        'click .search-tab': (e) => {
          this.activeType = e.target.dataset.type;
          this.render();
        },

        'submit form.new-text': (e) => {
          e.preventDefault();
          e.stopPropagation();
          post(FRONTEND_URLS.new_section_or_resource.replace('$CASEBOOK_ID', this.casebookId()), {
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
          post(FRONTEND_URLS.new_section_or_resource.replace('$CASEBOOK_ID', this.casebookId()), {
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
            request = Axios.get(FRONTEND_URLS.search, {
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
            post(FRONTEND_URLS.new_section_or_resource.replace('$CASEBOOK_ID', this.casebookId()),
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
    super.render();
    if (this.activeType === 'text') {
      global.initRichTextEditor(document.getElementById('add_resource_text_content'));
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
            <h4 class="modal-title">Add Resource</h4>
          </div>
          <div class="modal-body">
            <div class="search-tabs">
              <div class="search-tab ${this.activeType === 'case' ? 'active' : ''}" data-type="case">
                Find Case
              </div>
              <div class="search-tab ${this.activeType === 'text' ? 'active' : ''}" data-type="text">
                Create Text
              </div>
              <div class="search-tab ${this.activeType === 'link' ? 'active' : ''}" data-type="link">
                Add Link
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
          <input class="form-control" name="q" type="text" value="${this.q}" placeholder="Search for a case to import" />
          <input class="search-button" type="submit" value="Search" />
        </form>
        ${raw(this.caseResultHtml || '')}
      </div>`;
    } else if (this.activeType == 'text') {
      return html`<div class="add-resource-body">
        <form class="new-text">
          <div class="form-group">
            <label class="title">
              Text title
              <input class="form-control" name="title" type="text" />
            </label>
          </div>
          <div class="form-group">
            <label>
              Text body
              <textarea id="add_resource_text_content" class="form-control" name="content" placeholder="Add and format text"></textarea>
            </label>
          </div>
          <input class="save-button" type="submit" value="Save text" />
        </form>
      </div>`;
    } else if (this.activeType == 'link') {
      return html`<div class="add-resource-body">
        <h3>Enter the URL of any asset to link from the web.</h3>
        <h4>Some examples: YouTube videos, PDFs, JPG, PNG, or GIF images</h4>
        <form class="new-link">
          <input class="form-control" name="url" type="text" placeholder="Enter a URL to add it to your casebook" />
          <input class="search-button" type="submit" value="Add linked resource" />
        </form>
      </div>`;
    }
  }
}
