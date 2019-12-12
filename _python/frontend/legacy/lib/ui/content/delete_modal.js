import {html, raw} from 'es6-string-html-template';
import delegate from 'delegate';
import Component from 'legacy/lib/ui/component';
import {rest_delete} from 'legacy/lib/requests';

delegate(document, '.action-delete', 'click', showDeleteModal);

function section_path(casebookId, sectionId) {
  return FRONTEND_URLS.section.replace('CASEBOOK_ID', casebookId).replace('SECTION_ID', sectionId);
}

let modal;  // eslint-disable-line no-unused-vars

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
        'click .close': () => { this.destroy() },
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
    if (!section || !section.classList.contains('section-wrapper')) { return 0 }
    return section.querySelectorAll('.listing-wrapper').length;
  }

  sectionTitle () {
    return this.deleteForm.closest('.listing-wrapper').querySelector('.section-title').innerText;
  }

  warningMessage () {
    if (this.nestedItems() === 0) {
      return `Are you sure you want to delete <strong>${this.sectionTitle()}</strong> from this casebook?`;
    } else {
      return `Are you sure you want to delete <strong>${this.sectionTitle()}</strong> and <strong>%{this.nestedItems()} nested items</strong> from this casebook?`;
    }
  }

  template () {
    return html`<div class="modal fade in" id="delete-modal" style="display: block">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <button type="button" class="close"><span>&times;</span></button>
            <h4 class="modal-title">Confirm Delete</h4>
          </div>
          <div class="modal-body">
            ${raw(this.warningMessage())}
          </div>
          <div class="modal-footer">
            <a href="" class="modal-button cancel">Cancel</a>
            <a href="" class="modal-button confirm">Delete</a>
          </div>
        </div>
      </div>
    </div>`
  }
}
