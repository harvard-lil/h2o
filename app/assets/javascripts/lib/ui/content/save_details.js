import delegate from 'delegate';

delegate(document, '.submit-edit-details', 'click', submitEditDetailsForm);
delegate(document, '.submit-section-details', 'click', submitSectionDetailsForm);
delegate(document, '.submit-casebook-details', 'click', submitCasebookDetailsForm);
delegate(document, '.cancel-casebook-details', 'click', cancelCasebookDetailsForm);

function submitEditDetailsForm (e) {
  e.preventDefault();
  document.querySelector('form.edit_content_resource').submit();
}

function submitSectionDetailsForm (e) {
  e.preventDefault();
  document.querySelector('form.edit_content_section').submit();
}

function submitCasebookDetailsForm (e) {
  e.preventDefault();
  document.querySelector('form.edit_content_casebook').submit();
}

function cancelCasebookDetailsForm (e) {
  e.preventDefault();
  window.location.reload(true);
}