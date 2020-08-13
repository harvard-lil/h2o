import {html} from 'es6-string-html-template';
import delegate from 'delegate';
import ModalComponent from 'legacy/lib/ui/modal';
import urls from 'libs/urls';

delegate(document, 'a.action.export', 'click', (e) => {
  e.preventDefault();
  // window.app is the Vue instance
  if((window.app && app.$store.getters['annotations/getCount'] > 0) ||
     (!window.app && e.target.classList.contains('export-has-annotations'))){
    showExportModal(e);
  } else {
    downloadFile();
  }
});

function resource_export_path(resourceId) {
    const url = urls.url('export_resource');
    return url({resourceId});
}

function section_export_path(sectionId) {
    const url =  urls.url('export_section');
    return url({sectionId});
}
function export_casebook_path(casebookId) {
    const url = urls.url('export_casebook');
    return url({casebookId});
}

function downloadFile (includeAnnotations) {
  if(typeof includeAnnotations === "undefined"){
    includeAnnotations = "true";
  }
  let pageInfo = document.querySelector('main > header').dataset;
  if (pageInfo.resourceId)  {
    window.location.assign(resource_export_path(pageInfo.resourceId) + (includeAnnotations === "true" ? '?annotations=true' : '?annotations=false'));
  } else if (pageInfo.sectionId)  {
    window.location.assign(section_export_path(pageInfo.sectionId) + (includeAnnotations === "true"? '?annotations=true' : '?annotations=false'));
  } else {
    window.location.assign(export_casebook_path(pageInfo.casebookId) + (includeAnnotations === "true" ? '?annotations=true' : '?annotations=false'));
  }
}

function showExportModal (e) {
  new ExportModal('export-modal', e.target, {
    'click #export-modal': (e) => { if (e.target.id === 'export-modal') this.destroy()},
    'click .export': (e) => {
      downloadFile(e.target.value);
      document.querySelector('button.close').click()
    }
  });
}

class ExportModal extends ModalComponent {
  casebookId () {
    return document.querySelector('header.casebook').dataset.casebookId;
  }

  sectionId () {
    return document.querySelector('header.casebook').dataset.sectionId;
  }

  template () {
    return html`<div class="modal fade in" id="${this.id}" style="display: block"  tabindex="-1" aria-labelledby="${this.id}-title">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <button type="button" class="close" aria-label="Close"><span aria-hidden="true">&times;</span></button>
            <h4 id="${this.id}-title" class="modal-title export-title">Export Casebook</h4>
          </div>
          <div class="modal-body">
            <div class="export-annotations">
              <button name="include-annotations" value=true class="modal-button export with-annotations">With annotations</button>
              <button name="include-annotations" value=false class="modal-button export no-annotations">Without annotations</button>
            </div>
          </div>
        </div>
      </div>
    </div>`
  }
}
