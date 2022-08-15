import ModalComponent from 'legacy/lib/ui/modal';
import delegate from 'delegate';
import {html} from 'es6-string-html-template';

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
            <p class="create-casebook-text">Would you like to make a new casebook from scratch or search for a casebook you can copy and customize?</p>

            <div class="modal-button-container">
              <div class="modal-button-box">
                <a href="/casebooks/new">
                  <span class="add-casebook" aria-hidden="true"></span>
                  <p class="modal-button-caption">
                    Make a New Casebook
                  </p>
                </a>
              </div>

              <div class="modal-button-box">
                <a href="/search">
                  <span class="customize-casebook" aria-hidden="true"></span>
                  <p class="modal-button-caption">
                    Search for a Casebook to Customize
                  </p>
                </a>
              </div>
            </div>
          
          </div>
          <div class="modal-footer"></div>
        </div>
      </div>
    </div>`
  }
}
