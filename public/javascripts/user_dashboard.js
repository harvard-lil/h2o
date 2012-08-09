jQuery.extend({
  updated_permissions: function(data) {
    jQuery('.extra' + data.id).append(jQuery('<span>Updated!</span>'));
    console.log(jQuery('.extra' + data.id));
    jQuery.hideGlobalSpinnerNode();
    jQuery('#generic-node').dialog('close');
    jQuery('.extra' + data.id + ' span').fadeOut(4000, function() { jQuery(this).remove(); });
  }
});

jQuery(function() {
  jQuery('#lookup_submit').live('click', function(e) {
    e.preventDefault();
    var link = jQuery(this);
    var type = link.data('type');
    if(jQuery(this).hasClass('disabled')) {
      return false;
    }
    jQuery.ajax({
      type: 'GET',
      cache: false,
      url: jQuery(this).attr('href'),
      dataType: "JSON",
      data: {
        lookup: jQuery('#lookup').val()
      },
      beforeSend: function() {
        jQuery.showGlobalSpinnerNode();
        link.addClass('disabled');
      },
      error: function(xhr){
        jQuery.hideGlobalSpinnerNode();
        link.removeClass('disabled');
        jQuery('#lookup_results li').remove();
        var node = jQuery('<li>');
        node.append(jQuery('<span>Error: please try again.</span>'));
        jQuery('#lookup_results').append(node);
      },
      success: function(results){
        jQuery('#lookup_results li').remove();
        jQuery('#lookup').val('');
        if(results.items.length == 0) {
          var node = jQuery('<li>');
          node.append(jQuery('<span>Could not find any ' + type + 's.</span>'));
          jQuery('#lookup_results').append(node);
        }
        jQuery.each(results.items, function(i, el) {
          var node = jQuery('<li class="item' + el.id + '">');
          node.append(jQuery('<span>' + el.display + '</span>'));
          if(jQuery('#current_list .item' + el.id).length) {
            node.append(jQuery('<span> (already added)</span>'));
          } else {
            node.append(jQuery('<a data-type="' + type + '" data-id="' + el.id + '">').attr('href', '#').addClass('add_item').html('ADD'));
          }
          jQuery('#lookup_results').append(node);
        });
        jQuery.hideGlobalSpinnerNode();
        link.removeClass('disabled');
      }
    });
  });
  jQuery('.remove_item').live('click', function(e) {
    e.preventDefault();
    jQuery(this).parent().remove();
  });
  jQuery('.add_item').live('click', function(e) {
    e.preventDefault();
    var link = jQuery(this);
    var cloned = link.parent().clone();
    cloned.append(jQuery('<input type="hidden">').attr('name', 'user_collection[' + link.data('type') + '_ids][]').val(link.data('id')));
    cloned.find('.add_item').removeClass('add_item').addClass('remove_item').html('REMOVE');
    jQuery('#current_list').append(cloned);
    link.parent().remove();
  });
});
