$('.view-searches-index, .view-searches-show').ready(e => {
  let selects = document.querySelectorAll('select');
  for (let el of selects) { el.value = el.value };

  $( "#search_author" ).select2({});

  $( "#search_school" ).select2({});

  $( "#search_sort" ).select2({});

  $('#search_author').on('select2:select', function (e) {
    e.target.closest('form').submit();
  });

  $('#search_school').on('select2:select', function (e) {
    e.target.closest('form').submit();
  });

  $('#search_sort').on('select2:select', function (e) {
    e.target.closest('form').submit();
  });
});
