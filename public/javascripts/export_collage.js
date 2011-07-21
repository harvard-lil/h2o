jQuery.extend({
	loadState: function() {
		jQuery('.collage-content').each(function(i, el) {
			var id = jQuery(el).data('id');
			var data = eval("collage_data_" + id);

			jQuery.each(data, function(i, e) {
				var id = jQuery(el).data('id');	//id value is lost here - not sure why
				if(i == 'highlights') {
					jQuery.each(e, function(a, h) {
						jQuery('#collage' + id + ' ' + a).css('background-color', '#' + h);
					});
				} else if(i == 'print_data') {
					// do nothing here
				} else if(i.match(/\.a/) && e != 'none') {
					jQuery('#collage' + id + ' ' + i).css('display', 'inline');
				} else if(i.match(/\.unlayered/)) {
					if(e == 'none') {
						// if unlayered text default is hidden,
						// add wrapper nodes with arrow for collapsing text
						// here!
						jQuery('#collage' + id + ' ' + i).addClass('default-hidden').css('display', 'none');
					} else {
						jQuery('#collage' + id + ' tt' + i).css('display', 'inline');
						jQuery('#collage' + id + ' p' + i + ', center' + i).css('display', 'block');
						//Remove unlayered collapse links here
						var id = i.match(/\d+/).toString();
						jQuery('.unlayered-control-' + id).remove();
					}
				} else {
					jQuery('#collage' + id + ' ' + i).css('display', e);
				}
			});
			if(data.print_data) {
				if(data.print_data.alltext) {
					jQuery('#collage' + id + ' .unlayered').show();
					jQuery('#collage' + id + ' .unlayered-ellipsis').hide();
				}
				if(data.print_data.allannotations) {
					jQuery('#collage' + id + ' .annotation-content').css('display', 'inline-block');
				}
				jQuery('.collage-content').css('font-size', data.print_data.fontsize + 'pt');
				jQuery('body,tt').css('font-family', data.print_data.fonttype);
			}
		});
	}
});

jQuery(document).ready(function(){
	jQuery.loadState();
});
