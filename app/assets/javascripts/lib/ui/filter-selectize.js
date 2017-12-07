$( "#search_author" ).select2({
    theme: "bootstrap"
});

$( "#search_school" ).select2({
    theme: "bootstrap"
});

$('#search_author').on('select2:select', function (e) {
  e.target.closest('form').submit();
});

$('#search_school').on('select2:select', function (e) {
  e.target.closest('form').submit();
});