$('.view-searches-index, .view-searches-show').ready(e => {

  $('#search_author').on('change', function (e) {
    e.target.closest('form').submit();
  });

  $('#search_school').on('change', function (e) {
    e.target.closest('form').submit();
  });

  $('#search_sort').on('change', function (e) {
    e.target.closest('form').submit();
  });
});
