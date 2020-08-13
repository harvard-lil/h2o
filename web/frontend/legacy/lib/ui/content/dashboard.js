import {html} from 'es6-string-html-template';
import delegate from 'delegate';
import ModalComponent from 'legacy/lib/ui/modal';


delegate(document, '[data-action="show-casebook-modal"]', 'click', (e) => showCasebookModal(e));

function showCasebookModal (e) {
  new NewCasebookModal('new-casebook-modal', e.target);
}

class NewCasebookModal extends ModalComponent {
  template () {
    return html`<div class="modal fade in" id="${this.id}" style="display: block"  tabindex="-1" aria-labelledby="${this.id}-title">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <button type="button" class="close" aria-label="Close"><span aria-hidden="true">&times;</span></button>
            <h4 id="${this.id}-title" class="modal-title">Create a Casebook</h4>
          </div>
          <div class="modal-body">
            Would you like to make a new casebook from scratch or search for a casebook you can copy and customize?
          </div>
          <div class="modal-footer">
            <a href="/casebooks/new" class="modal-button">Make a New Casebook</a>
            <a href="/search" class="modal-button">Search Casebooks</a>
          </div>
        </div>
      </div>
    </div>`
  }
}
