import './ckeditor_set_path.js.erb';
import 'ckeditor';

$(document).ready(e => {
  for(name in CKEDITOR.instances) {
    CKEDITOR.instances[name].destroy(true);
  }
  for (let el of document.querySelectorAll('.ckeditor')) {
    CKEDITOR.replace(el.id, {toolbar: 'mini'});
  }
});
