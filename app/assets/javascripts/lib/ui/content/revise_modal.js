import {html} from 'es6-string-html-template';
import delegate from 'delegate';
import ModalComponent from 'lib/ui/modal';

delegate(document, '.create-draft', 'click', showReviseModal);

function showReviseModal (e) {
  new ReviseModal('revise-modal', e.target, {});

  e.currentTarget.activeElement.dataset.processing = "true" // override the component destroy events
}

class ReviseModal extends ModalComponent {

  template () {
    return html`<div class="modal fade in" id="${this.id}" style="display: block" tabindex="-1" aria-labelledby="${this.id}-title">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="spinner-group">
            <p class="spinner-header">Building draft</p>
            <p class="spinner-description">Your casebook will remain published and you can merge in any changes when you're ready.</p>
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
