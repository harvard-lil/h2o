jQuery(function() {
  jQuery('#email_lookup_submit').live('click', function(e) {
    e.preventDefault();
    var link = jQuery(this);
    if(jQuery(this).hasClass('disabled')) {
      return false;
    }
    jQuery.ajax({
      type: 'GET',
      cache: false,
      url: jQuery(this).attr('href'),
      dataType: "JSON",
      data: {
        user_lookup: jQuery('#user_lookup').val()
      },
      beforeSend: function() {
        jQuery.showGlobalSpinnerNode();
        link.addClass('disabled');
      },
      error: function(xhr){
        jQuery.hideGlobalSpinnerNode();
        link.removeClass('disabled');
        jQuery('#email_lookup_results li').remove();
        var node = jQuery('<li>');
        node.append(jQuery('<span>Error: please try again.</span>'));
        jQuery('#email_lookup_results').append(node);
      },
      success: function(results){
        jQuery('#email_lookup_results li').remove();
        jQuery('#user_lookup').val('');
        if(results.users.length == 0) {
          var node = jQuery('<li>');
          node.append(jQuery('<span>Could not find any users.</span>'));
          jQuery('#email_lookup_results').append(node);
        }
        jQuery.each(results.users, function(i, el) {
          var node = jQuery('<li>');
          node.append(jQuery('<span>' + el.user.login + '(' + el.user.email_address + ')</span>'));
          node.append(jQuery('<input type="hidden">').attr('name', 'user_collection[user_ids][]').val(el.user.id));
          node.append(jQuery('<a>').attr('href', '#').addClass('add_user').html('ADD'));
          jQuery('#email_lookup_results').append(node);
        });
        jQuery.hideGlobalSpinnerNode();
        link.removeClass('disabled');
      }
    });
  });
  jQuery('.remove_user').live('click', function(e) {
    e.preventDefault();
    jQuery(this).parent().remove();
  });
  jQuery('.add_user').live('click', function(e) {
    e.preventDefault();
    jQuery('#user_list').append(jQuery(this).parent().clone());
    jQuery('#user_list .add_user').removeClass('add_user').addClass('remove_user').html('REMOVE');
    jQuery(this).parent().remove();
  });
});
