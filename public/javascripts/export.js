jQuery.extend({
	loadState: function() {
		jQuery('.collage-content').each(function(i, el) {
			var id = jQuery(el).data('id');
			var data = eval("collage_data_" + id);
			jQuery('.unlayered-control').remove();

			jQuery.each(data, function(i, e) {
				var id = jQuery(el).data('id');	//id value is lost here - not sure why
				if(i == 'highlights') {
					jQuery.each(e, function(a, h) {
						jQuery('#collage' + id + ' ' + a).css('background-color', '#' + h);
					});
				} else if(i == 'print_data') {
          //Do Nothing until the end
				} else if(i.match(/\.a/) && e != 'none') {
					jQuery('#collage' + id + ' ' + i).css('display', 'inline');
				} else if(i.match(/#annotation-content-/) && e != 'none') {
					jQuery('#collage' + id + ' ' + i).css('display', 'block');
				} else if(i.match(/\.unlayered/)) {
					if(e == 'none') {
						jQuery('#collage' + id + ' ' + i).css('display', 'none');
					} else {
						jQuery('#collage' + id + ' tt' + i).css('display', 'inline');
						jQuery('#collage' + id + ' p' + i + ', center' + i).css('display', 'block');
					}
				} else {
					jQuery('#collage' + id + ' ' + i).css('display', e);
				}
			});
      /* Single Collage Only */
      if(data.print_data) {
        if(data.print_data.alltext) {
          jQuery('.unlayered').show();
          jQuery('.unlayered-ellipsis').remove();
        }
        if(data.print_data.allannotations) {
          jQuery('.annotation-content').css('display', 'inline-block');
        }
        jQuery('.collage-content').css('font-size', data.print_data.fontsize + 'pt');
        jQuery('.collage-content .info, .collage-content .desc').css('font-size', (parseInt(data.print_data.fontsize) + 1) + 'pt');
        jQuery('.collage-content h2').css('font-size', (parseInt(data.print_data.fontsize) + 3) + 'pt');
        jQuery('body,tt').css('font-family', data.print_data.fonttype);
      }
		});
	}
});

jQuery(document).ready(function(){
	jQuery.loadState();
  jQuery('#printfonttype').selectbox({
    className: "jsb", replaceInvisible: true 
  }).change(function() {
  	jQuery('body,tt').css('font-family', jQuery(this).val());
  });
  jQuery('#printfontsize').selectbox({
    className: "jsb", replaceInvisible: true 
  }).change(function() {
    var size = jQuery(this).val();
    jQuery('body,tt,.collage-content,#playlist #description').css('font-size', size + 'pt');
    jQuery('#playlist h1').css('font-size', (parseInt(size) + 6) + 'pt');
    jQuery('#playlist h3').css('font-size', (parseInt(size) + 3) + 'pt');
    jQuery('#playlist .details h2').css('font-size', (parseInt(size) - 1) + 'pt');
  });
  jQuery('.unlayered-ellipsis').replaceWith('<span class="unlayered-ellipsis">[...]</span>');
});
