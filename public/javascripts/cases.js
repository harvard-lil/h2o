$.extend({
  case_afterload: function(results) {
    if(results.can_edit) {
      $('.requires_edit').animate({ opacity: 1.0 });
    } else {
      $('.requires_edit').remove();
    }
  },
  case_jurisdiction_post: function(data) {
    if(data.update) {
      $('#case_case_jurisdiction_id option[value=' + data.id + ']').html(data.name);
    } else {
      var option = $('<option>').val(data.id).html(data.name);
      $('#case_case_jurisdiction_id').append(option).val(data.id);
    }
    $.hideGlobalSpinnerNode();
    $('#generic-node').dialog('close');
  },
  initializeFontChange: function() {
    var val = $.cookie('font_size');
    if (val == null){
      val = 16;
    }
    if(val != null) {
      $('.font-size-popup select').val(val);
      $('#case article').css('font-size', parseInt(val) + 1 + 'px');
      $('#description_less, #description_more, #description').css('font-size', (parseInt(val) + 2) + 'px');
      $('#case .details h5').css('font-size', parseInt(val) + 1 + 'px');
    }
  }      
});

$(document).ready(function(){
  if($('.description').length) {
    var height = $('.description').height();
    if(height != 30) {
      $('.toolbar,.buttons').css({ position: 'relative', top: height - 30 });
    }
    $('.toolbar, .buttons').css('visibility', 'visible');
  }

  $(document).delegate('.edit-case-jurisdiction', 'click', function(e) {
    e.preventDefault();
    var id = $('#case_case_jurisdiction_id').val();
    if(id == '') {
      return;
    }
    var url = '/case_jurisdictions/' + id + '/edit';
    $.ajax({
      cache: false,
      url: url,
      beforeSend: function() {
        $.showGlobalSpinnerNode();
      },  
      success: function(html) {
        $.hideGlobalSpinnerNode();
        $.generateGenericNode(html);
      },  
      error: function(xhr, textStatus, errorThrown) {
        $.hideGlobalSpinnerNode();
      }
    });
  });
  $.observeMetadataForm();

  $('form a.add_child').click(function() {
    var assoc   = $(this).attr('data-association');
    var content = $('#' + assoc + '_fields_template').html();
    var regexp  = new RegExp('new_' + assoc, 'g');
    var new_id  = new Date().getTime();
        
    $(this).parent().before(content.replace(regexp, new_id));    
    return false;
  });
  
  $(document).delegate('form a.remove_child', 'click', function() {
    var hidden_field = $(this).prev('input[type=hidden]')[0];
    if(hidden_field) {
      hidden_field.value = '1';
    }
    $(this).parents('.fields').hide();
    return false;
  });
  $.initializeFontChange();
});
