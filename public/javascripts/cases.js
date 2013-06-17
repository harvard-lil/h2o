jQuery.extend({
  case_afterload: function(results) {
    if(results.can_edit) {
      jQuery('.requires_edit').animate({ opacity: 1.0 });
    } else {
      jQuery('.requires_edit').remove();
    }
  },
  case_jurisdiction_post: function(data) {
    if(data.update) {
      jQuery('#case_case_jurisdiction_id option[value=' + data.id + ']').html(data.name);
    } else {
      var option = jQuery('<option>').val(data.id).html(data.name);
      jQuery('#case_case_jurisdiction_id').append(option).val(data.id);
    }
    jQuery.hideGlobalSpinnerNode();
    jQuery('#generic-node').dialog('close');
  },
  initializeFontChange: function() {
    var val = jQuery.cookie('font_size');
    if (val == null){
      val = 16;
    }
    if(val != null) {
      jQuery('.font-size-popup select').val(val);
      jQuery('#case article').css('font-size', parseInt(val) + 1 + 'px');
      jQuery('#description_less, #description_more, #description').css('font-size', (parseInt(val) + 2) + 'px');
      jQuery('#case .details h5').css('font-size', parseInt(val) + 1 + 'px');
    }
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
  jQuery.observeMetadataForm();

  jQuery('form a.add_child').click(function() {
    var assoc   = jQuery(this).attr('data-association');
    var content = jQuery('#' + assoc + '_fields_template').html();
    var regexp  = new RegExp('new_' + assoc, 'g');
    var new_id  = new Date().getTime();
        
    jQuery(this).parent().before(content.replace(regexp, new_id));    
    return false;
  });
  
  jQuery('form a.remove_child').live('click', function() {
    var hidden_field = jQuery(this).prev('input[type=hidden]')[0];
    if(hidden_field) {
      hidden_field.value = '1';
    }
    jQuery(this).parents('.fields').hide();
    return false;
  });
  jQuery.initializeFontChange();
});
