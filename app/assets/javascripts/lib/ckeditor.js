//= require ckeditor/init

document.addEventListener('turbolinks:load', e => {
  for(name in CKEDITOR.instances) {
      CKEDITOR.instances[name].destroy(true);
  }
  for (let el of document.querySelectorAll('[data-ckeditor]')) {
    CKEDITOR.replace(el.id, {toolbar: 'mini'});
  }
});
