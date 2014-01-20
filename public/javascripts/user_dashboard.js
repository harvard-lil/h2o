$.extend({
  renderDeleteFunctionality: function() {
    if('/users/' + $.cookie('user_id') == document.location.pathname) {
      $.each($('#results_set li'), function(i, el) {
        var delete_link = $('<a>')
                            .addClass('icon icon-delete tooltiip')
                            .attr('title', 'Delete')
                            .html('DELETE')
                            .data('type', $(el).data('type'))
                            .attr('href', '/' + $(el).data('type') + 's/' + $(el).data('itemid'));
        $(el).find('.details h3').append(delete_link);
      });
    }
  },
  updated_permissions: function(data) {
    $('.extra' + data.id).append($('<span>Updated!</span>'));
    $.hideGlobalSpinnerNode();
    $('#generic-node').dialog('close');
    $('.extra' + data.id + ' span').fadeOut(4000, function() { $(this).remove(); });
  },
  observeCaseApproval: function() {
    $(document).delegate('.approve-action', 'click', function(e) {
      e.preventDefault();
  
      var approveUrl = $(this).attr('href');
      var item_id = approveUrl.match(/[0-9]+/).toString();
      $.ajax({
        cache: false,
        type: 'POST',
        url: approveUrl,
        dataType: 'JSON',
        data: {},
        beforeSend: function(){
          $.showGlobalSpinnerNode();
        },
        error: function(xhr){
          $.hideGlobalSpinnerNode();
        },
        success: function(data){
          $(".listitem" + item_id).animate({ opacity: 0.0, height: 0 }, 500, function() {
            $(".listitem" + item_id).remove();
          });
          $.hideGlobalSpinnerNode();
        }
      });
    });
  },
  observeCollectionActions: function() {
    $(document).delegate('#lookup_submit', 'click', function(e) {
      e.preventDefault();
      var link = $(this);
      var type = link.data('type');
      if($(this).hasClass('disabled')) {
        return false;
      }
      $.ajax({
        type: 'GET',
        cache: false,
        url: $(this).attr('href'),
        dataType: "JSON",
        data: {
          lookup: $('#lookup').val()
        },
        beforeSend: function() {
          $.showGlobalSpinnerNode();
          link.addClass('disabled');
        },
        error: function(xhr){
          $.hideGlobalSpinnerNode();
          link.removeClass('disabled');
          $('#lookup_results li').remove();
          var node = $('<li>');
          node.append($('<span>Error: please try again.</span>'));
          $('#lookup_results').append(node);
        },
        success: function(results){
          $('#lookup_results li').remove();
          $('#lookup').val('');
          if(results.items.length == 0) {
            var node = $('<li>');
            node.append($('<span>Could not find any ' + type + 's.</span>'));
            $('#lookup_results').append(node);
          }
          $.each(results.items, function(i, el) {
            var node = $('<li class="item' + el.id + '">');
            node.append($('<span>' + el.display + '</span>'));
            if($('#current_list .item' + el.id).length) {
              node.append($('<span> (already added)</span>'));
            } else {
              node.append($('<a data-type="' + type + '" data-id="' + el.id + '">').attr('href', '#').addClass('add_item').html('ADD'));
            }
            $('#lookup_results').append(node);
          });
          $.hideGlobalSpinnerNode();
          link.removeClass('disabled');
        }
      });
    });
    $(document).delegate('.remove_item', 'click', function(e) {
      e.preventDefault();
      $(this).parent().remove();
    });
    $(document).delegate('.add_item', 'click', function(e) {
      e.preventDefault();
      var link = $(this);
      var cloned = link.parent().clone();
      cloned.append($('<input type="hidden">').attr('name', 'user_collection[' + link.data('type') + '_ids][]').val(link.data('id')));
      cloned.find('.add_item').removeClass('add_item').addClass('remove_item').html('REMOVE');
      $('#current_list').append(cloned);
      link.parent().remove();
    });
  },
  listResultsSpecial: function(url, region, store_address) {
    list_results_url = url;

    $.ajax({
      type: 'GET',
      dataType: 'html',
      url: url,
      beforeSend: function(){
           $.showGlobalSpinnerNode();
         },
         error: function(xhr){
           $.hideGlobalSpinnerNode();
      },
      success: function(html){
        if(store_address) {
          $.address.value(url);
        }
        $.hideGlobalSpinnerNode();
        $('#results_' + region).html(html);
        $('#pagination_' + region).html($('#new_pagination').html());
        $('#new_pagination').remove();
        $.initializeBarcodes();
        $('#results_' + region + ' .listitem').hoverIntent(function() {
        $(this).addClass('hover');
        $(this).find('.icon').addClass('hover');
        }, function() {
          $(this).removeClass('hover');
          $(this).find('.icon').removeClass('hover');
        });
      }
    });
  },
  observeSpecialPagination: function() {
    $('.special_sort select').selectbox({
      className: "jsb", replaceInvisible: true 
    }).change(function() {
      var sort = $(this).val();
      var region = $(this).parent().parent().data('region');
      var url = document.location.pathname + '?ajax_region=' + region + '&sort=' + sort;
      /*if($('#user_search_filter select').val() != 'all_materials') {
        url += '&filter_type=' + $('#user_search_filter select').val();
      } */
      $.listResultsSpecial(url, region, true);
    });
    $(document).delegate('.users_pagination a', 'click', function(e) {
      e.preventDefault();
      var href = $(this).attr('href');
      var region = $(this).parent().data('region');
      $.listResultsSpecial(href, region, true);
    });
  },
  observeKeywordsSearch: function() {
    $('#search_user_content').click(function(e){
      var url = document.location.pathname + '?keywords=' + $('#user_keywords').val() + '&sort=' + $('#user_sort select').val();
      if($('#user_search_filter select').val() != 'all_materials') {
        url += '&filter_type=' + $('#user_search_filter select').val();
      }
      $.showGlobalSpinnerNode();
      $.address.value(url);
      $('#results_set').load(url, function() { 
        $.hideGlobalSpinnerNode(); 
        $.renderDeleteFunctionality();
        
        $('.standard_pagination').html($('#new_pagination').html());
        $('#new_pagination').remove();
      });
    });
  }
});

$(function() {
  $.observeCaseApproval();
  $.observeCollectionActions();
  $.observeSpecialPagination();
  $.observeKeywordsSearch();
  $.renderDeleteFunctionality();
});
