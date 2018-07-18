h2o_global.case_afterload = function(results) {
    if(results.can_edit) {
      $('.requires_edit').animate({ opacity: 1.0 });
    } else {
      $('.requires_edit').remove();
    }
};
h2o_global.case_court_post = function(data) {
    if(data.update) {
      $('#case_case_court_id option[value=' + data.id + ']').html(data.name);
    } else {
      var option = $('<option>').val(data.id).html(data.name);
      $('#case_case_court_id').append(option).val(data.id);
    }
    h2o_global.hideGlobalSpinnerNode();
    $('#generic-node').dialog('close');
};

var cases_new = {
  initialize_font_change: function() {
    var val = $.cookie('default_font_size');
    if (val == null){
      val = 16;
    }
    if(val != null) {
      $('.font-size-popup select').val(val);
      $('#case div.article').css('font-size', parseInt(val) + 1 + 'px');
      $('#description_less, #description_more, #description').css('font-size', (parseInt(val) + 2) + 'px');
      $('#case .details h5').css('font-size', parseInt(val) + 1 + 'px');
    }
  },
  initialize: function() {
    if($('.description').length) {
	    var height = $('.description').height();
	    if(height != 30) {
	      $('.toolbar,.buttons').css({ position: 'relative', top: height - 30 });
	    }
	    $('.toolbar, .buttons').css('visibility', 'visible');
	  }
	
	  $(document).delegate('.edit-case-jurisdiction', 'click', function(e) {
	    e.preventDefault();
	    var id = $('#case_case_court_id').val();
	    if(id == '') {
	      return;
	    }
	    var url = '/case_courts/' + id + '/edit';
	    $.ajax({
	      cache: false,
	      url: url,
	      beforeSend: function() {
	        h2o_global.showGlobalSpinnerNode();
	      },  
	      success: function(html) {
	        h2o_global.hideGlobalSpinnerNode();
	        h2o_global.generateGenericNode(html);
	      },  
	      error: function(xhr, textStatus, errorThrown) {
	        h2o_global.hideGlobalSpinnerNode();
	      }
	    });
	  });
	  h2o_global.observeMetadataForm();

    $.each(['case_docket_number', 'case_citation'], function(i, type) {
		  $('form a.add_' + type).click(function(e) {
	      e.preventDefault();
	
	      var new_node = $($.mustache(cases_new[type + '_template'], {}));
	      new_node.insertBefore($(this).parent());
	      eval('cases_new.update_' + type + '_keys()');
		  });
		 
		  $(document).delegate('form a.remove_' + type, 'click', function(e) {
	      e.preventDefault();
	
	      if($(this).hasClass('existing_' + type)) {
	        var visible_li = $(this).parentsUntil('li').parent();
	        visible_li.next('li').find('input').val("1");
	        visible_li.hide();
          if(type == 'case_citation') {
	          visible_li.prev('li').hide();
	          visible_li.prev('li').prev('li').hide();
          }
	      } else {
	        $(this).parent().remove();
	      }
	      eval('cases_new.update_' + type + '_keys()');
		  });
    });

	  cases_new.initialize_font_change();
  },
  update_case_docket_number_keys: function() {
    var start_count = $('a.existing_case_docket_number').size();
    $.each($('input.case_docket_input'), function(i, el) {
      $(el)
        .attr('id', 'case_case_docket_numbers_attributes_' + parseInt(start_count + i) + '_docket_number')
        .attr('name', 'case[case_docket_numbers_attributes][' + parseInt(start_count + i) + '][docket_number]');
    });
  },
  update_case_citation_keys: function() {
    var start_count = $('a.existing_case_citation').size();
    $.each(['volume', 'reporter', 'page'], function(a, key) {
      $.each($('input.case_citation_input_' + key), function(i, el) {
        $(el)
          .attr('id', 'case_case_citations_attributes_' + parseInt(start_count + i) + '_' + key)
          .attr('name', 'case[case_citations_attributes][' + parseInt(start_count + i) + '][' + key + ']');
      });
    });
  },
  case_docket_number_template: '<li class="new_record"><label>Docket number <abbr title="required">*</abbr></label>\
<input class="case_docket_input" type="text" maxlength="200" \><br />\
<a href="#" class="remove_case_docket_number">REMOVE</a></li>',
  case_citation_template: '<li class="new_record">\
<label>Volume <abbr title="required">*</abbr></label>\
<input class="case_citation_input_volume" type="text" maxlength="200" \><br />\
<label>Reporter <abbr title="required">*</abbr></label>\
<input class="case_citation_input_reporter" type="text" maxlength="200" \><br />\
<label>Page <abbr title="required">*</abbr></label>\
<input class="case_citation_input_page" type="text" maxlength="200" \><br />\
<a href="#" class="remove_case_citation">REMOVE</a></li>'
};

var cases_edit = cases_new;
var cases_create = cases_new;
