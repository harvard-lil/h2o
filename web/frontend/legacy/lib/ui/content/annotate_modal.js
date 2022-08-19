import ModalComponent from 'legacy/lib/ui/modal';
import delegate from 'delegate';
import {html} from 'es6-string-html-template';

delegate(document, '.annotate-casebook', 'click', showAnnotateModal);

function showAnnotateModal (e) {
  new AnnotateModal('clone-modal', e.target, {});

  e.currentTarget.activeElement.dataset.processing = "true" // override the component destroy events
}

class AnnotateModal extends ModalComponent {
  template () {
    return html`<div class="modal fade in" id="${this.id}" tabindex="-1" aria-label="${this.id}-title" style="display: block">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="spinner-group">
            <p class="spinner-header">Copying for Taking Notes</p>
            <p>You can view this copy on your Dashboard</p>
            <span class=""></span>
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
