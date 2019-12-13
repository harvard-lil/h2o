$(document).ready(e => {

  if($('.view-searches-index, .view-searches-show').length){

    $('#search_author').on('change', function (e) {
      e.target.closest('form').submit();
    });

    $('#search_school').on('change', function (e) {
      e.target.closest('form').submit();
    });

    $('#search_sort').on('change', function (e) {
      e.target.closest('form').submit();
    });
  }

});
