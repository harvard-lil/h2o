import {html} from 'es6-string-html-template';
import delegate from 'delegate';
import Component from 'lib/ui/component';

delegate(document, '.clone-casebook', 'submit', showCloneModal);

let modal = null;

document.addEventListener("turbolinks:before-cache", function() {
  if (modal) { modal.destroy(); }
});

function showCloneModal (e) {
  e.preventDefault();
  e.stopPropagation();
  modal = new CloneModal;
}

class CloneModal extends Component {
  constructor () {
    super({id: 'clone-modal'});
    document.body.appendChild(this.el);
    this.render();
  }

  destroy () {
    modal = null;
  }

  template () {
    return html`<div class="modal fade in" id="publish-modal" style="display: block">
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