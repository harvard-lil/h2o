import {html} from 'es6-string-html-template';
import delegate from 'delegate';
import ModalComponent from 'legacy/lib/ui/modal';
import {patch} from 'legacy/lib/requests';
import urls from 'libs/urls';

delegate(document, 'button.action.publish', 'click', showPublishModal);

function casebook_path(casebookId) {
  return urls.url('casebook')({casebookId});
}

function showPublishModal (e) {
  let modal = new PublishModal('publish-modal', e.target, {
    'click .confirm': (e) => {
      showSpinner();
      e.currentTarget.dataset.processing = "true" // override the component destroy events
      let casebookId = document.querySelector('main > header').dataset.casebookId;
      // TODO: I think this wants to be a standard POST form submission.
      // It doesn't even need to be AJAX, since publishing should never fail,
      // and we need to re-render the whole page or redirecting to another page after success.
      patch(casebook_path(casebookId), {content_casebook: {public: true}}, {modal: modal});
    },
  });
}

function showSpinner () {
  $(".modal-header").hide();
  $(".modal-body").hide();
  $(".modal-footer").hide();
  $(".spinner-group").show().css('display', 'flex');
  $(".spinner").show();
  $(".spinner-header").show();
}

class PublishModal extends ModalComponent {

  casebookId () {
    return document.querySelector('header.casebook').dataset.casebookId;
  }

  sectionId () {
    return document.querySelector('header.casebook').dataset.sectionId;
  }

  template () {
    return html`<div class="modal fade in" id="${this.id}" style="display: block" tabindex="-1" aria-labelledby="${this.id}-title">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <button type="button" class="close" aria-label="Close"><span aria-hidden="true">&times;</span></button>
            <h4 id="${this.id}-title" class="modal-title">Confirm Publish</h4>
          </div>
          <div class="publish">
            <div class="spinner-group">
              <span class="spinner-header">Publishing</span>
              <div class="spinner">
                <div class="bounce1"></div>
                <div class="bounce2"></div>
                <div class="bounce3"></div>
              </div>
            </div>
          </div>
          <div class="modal-body">
            Are you ready to publish your book?
          </div>
          <div class="modal-footer">
            <button class="modal-button cancel">No</button>
            <button class="modal-button confirm">Yes</button>
          </div>
        </div>
      </div>
    </div>`
  }
}
