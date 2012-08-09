jQuery.extend({
  case_jurisdiction_post: function(data) {
    if(data.update) {
      jQuery('#case_case_jurisdiction_id option[value=' + data.id + ']').html(data.name);
    } else {
      var option = jQuery('<option>').val(data.id).html(data.name);
      jQuery('#case_case_jurisdiction_id').append(option).val(data.id);
    }
    jQuery.hideGlobalSpinnerNode();
    jQuery('#generic-node').dialog('close');
  }
});

jQuery(document).ready(function(){
  if(jQuery('.description').length) {
    var height = jQuery('.description').height();
    if(height != 30) {
      jQuery('.toolbar,.buttons').css({ position: 'relative', top: height - 30 });
    }
    jQuery('.toolbar, .buttons').css('visibility', 'visible');
  }

  jQuery('.edit-case-jurisdiction').live('click', function(e) {
    e.preventDefault();
    var id = jQuery('#case_case_jurisdiction_id').val();
    if(id == '') {
      return;
    }
    var url = '/case_jurisdictions/' + id + '/edit';
    jQuery.ajax({
      cache: false,
      url: url,
      beforeSend: function() {
        jQuery.showGlobalSpinnerNode();
      },  
      success: function(html) {
        jQuery.hideGlobalSpinnerNode();
        jQuery.generateGenericNode(html);
      },  
      error: function(xhr, textStatus, errorThrown) {
        jQuery.hideGlobalSpinnerNode();
      }
    });
  });
});
