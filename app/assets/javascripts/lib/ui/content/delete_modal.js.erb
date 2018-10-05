<% include Rails.application.routes.url_helpers %>
<% include ActionView::Helpers::JavaScriptHelper %>

import {html, raw} from 'es6-string-html-template';
import delegate from 'delegate';
import Component from 'lib/ui/component';
import {rest_delete} from 'lib/requests';

delegate(document, '.action-delete', 'click', showDeleteModal);

function section_path(casebookId, sectionId) {
  return '<%= j section_path('CASEBOOK_ID', 'SECTION_ID') %>'.replace('CASEBOOK_ID', casebookId).replace('SECTION_ID', sectionId);
}

let modal = null;

function showDeleteModal (e) {
  e.preventDefault();
  e.stopPropagation();
  modal = new DeleteModal(e.target.parentElement);
}

class DeleteModal extends Component {
  constructor (form) {
    super({
      id: 'delete-modal',
      events: {
        'click #delete-modal': (e) => { if (e.target.id === 'delete-modal') this.destroy()},
        'click .close': (e) => { this.destroy() },
        'click .cancel': (e) => { 
          e.preventDefault();
          e.stopPropagation();
          this.destroy() 
        },
        'click .confirm': (e) => {
          e.preventDefault();
          e.stopPropagation();
          let casebookId = document.querySelector('header.casebook').dataset.casebookId
          let sectionOrdinals = this.deleteForm.closest('.listing-wrapper').dataset.ordinals;

          rest_delete(section_path(casebookId, sectionOrdinals), {});
        },
      }
    });
    this.deleteForm = form;
    document.body.appendChild(this.el);
    this.render();
  }

  casebookId () {
    return document.querySelector('header.casebook').dataset.casebookId;
  }

  sectionId () {
    return document.querySelector('header.casebook').dataset.sectionId;
  }

  destroy () {
    super.destroy();
    modal = null;
  }

  nestedItems () {
    let section = this.deleteForm.closest('.listing-wrapper').nextElementSibling;
    if (!section || !section.classList.contains('section-wrapper')) { return 0 };
    return section.querySelectorAll('.listing-wrapper').length;
  }

  sectionTitle () {
    return this.deleteForm.closest('.listing-wrapper').querySelector('.section-title').innerText;
  }

  warningMessage () {
    if (this.nestedItems() === 0) {
      return "<%= j(I18n.t 'content.delete-modal.body.html', section_name: '_TITLE')%>".replace('_TITLE', this.sectionTitle());
    } else {
      return "<%= j(I18n.t 'content.delete-modal.body.nested.html', section_name: '_TITLE', nested_items: '_ITEMS')%>".replace('_TITLE', this.sectionTitle()).replace('_ITEMS', this.nestedItems());
    }
  }

  template () {
    return html`<div class="modal fade in" id="delete-modal" style="display: block">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <button type="button" class="close"><span>&times;</span></button>
            <h4 class="modal-title"><%= I18n.t 'content.delete-modal.title' %></h4>
          </div>
          <div class="modal-body">
            ${raw(this.warningMessage())}
          </div>
          <div class="modal-footer">
            <a href="" class="modal-button cancel"><%= I18n.t 'content.delete-modal.cancel' %></a>
            <a href="" class="modal-button confirm"><%= I18n.t 'content.delete-modal.confirm' %></a>
          </div>
        </div>
      </div>
    </div>`
  }
}
