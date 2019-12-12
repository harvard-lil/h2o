import {html} from 'es6-string-html-template';
import delegate from 'delegate';
import ModalComponent from 'lib/ui/modal';

delegate(document, '.clone-casebook', 'click', showCloneModal);

function showCloneModal (e) {
  new CloneModal('clone-modal', e.target, {});

  e.currentTarget.activeElement.dataset.processing = "true" // override the component destroy events
}

class CloneModal extends ModalComponent {
  template () {
    return html`<div class="modal fade in" id="${this.id}" tabindex="-1" aria-label="${this.id}-title" style="display: block">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="spinner-group">
            <p class="spinner-header">Cloning casebook</p>
            <div class="spinner">
              <div class="bounce1"></div>
              <div class="bounce2"></div>
              <div class="bounce3"></div>
            </div>
          </div>
        </div>
      </div>
    </div>`
  }
}
