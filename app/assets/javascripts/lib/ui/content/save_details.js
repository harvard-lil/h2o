import delegate from 'delegate';

delegate(document, '.submit-resource-details', 'click', submitEditDetailsForm);
delegate(document, '.cancel-resource-details', 'click', cancelDetailsForm);
delegate(document, '.submit-section-details', 'click', submitSectionDetailsForm);
delegate(document, '.cancel-section-details', 'click', cancelDetailsForm);
delegate(document, '.submit-casebook-details', 'click', submitCasebookDetailsForm);
delegate(document, '.cancel-casebook-details', 'click', cancelDetailsForm);

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

function cancelDetailsForm (e) {
  e.preventDefault();
  window.location.reload(true);
}
