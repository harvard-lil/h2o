document.addEventListener('turbolinks:load', e => {
  $( "#search_author" ).select2({});

  $( "#search_school" ).select2({});

  $( "#search_sort" ).select2({});

  $('#search_author').on('select2:select', function (e) {
    e.target.closest('form').submit();
  });

  $('#search_school').on('select2:select', function (e) {
    e.target.closest('form').submit();
  });
});

