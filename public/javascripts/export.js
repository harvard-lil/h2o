jQuery.extend({
	loadState: function() {
    jQuery('tt').prepend($('<span>').addClass('print_border'));

		jQuery('.collage-content').each(function(i, el) {
			var id = jQuery(el).data('id');
			var data = eval("collage_data_" + id);
      var line_height = $('tt:first').css('line-height');

			jQuery.each(data, function(i, e) {
        //id value is lost here - not sure why
				var id = jQuery(el).data('id');	

				if(i == 'highlights') {
					jQuery.each(e, function(a, h) {
            jQuery('#collage' + id + ' .' + a + ' .print_border').append(jQuery('<span>').css({ 'border-top': line_height + ' solid #' + h }));
					});
				} else if(i == 'print_data') {
          //Do Nothing until the end
				} else if(i.match(/\.a/) && e != 'none') {
          jQuery.rule('#collage' + id + ' ' + i + ' { display: inline; }').appendTo('style');
				} else if(i.match(/#annotation-content-/) && e != 'none') {
          jQuery.rule('#collage' + id + ' ' + i + ' { display: block; }').appendTo('style');
				} else if(i.match(/\.unlayered/) && e != 'none') {
          jQuery.rule('#collage' + id + ' ' + i + ' { display: inline; }').appendTo('style');
          jQuery.rule('#collage' + id + ' p' + i + ', #collage' + id + ' center' + i + ' { display: block; }').appendTo('style');
				} else {
          jQuery.rule('#collage' + id + ' ' + i + ' { display: ' + e + '; }').appendTo('style');
				}
			});

      var max_children = 0;
      jQuery.each(jQuery('#collage' + id + ' .print_border'), function(i, el) {
        if(jQuery(el).children().size() > max_children) {
          max_children = jQuery(el).children().size();
        }   
      }); 
      jQuery('#collage' + id + ' .print_border span').css({ 'opacity' : 0.50/max_children }); 
		});

    /* Single Collage Only */
    jQuery('.unlayered-ellipsis').each(function(e, el) {
      var item = jQuery(el);
      item.replaceWith('<span id="' + item.attr('id') + '" class="unlayered-ellipsis">[...]</span>');
    });
	}
});

jQuery(document).ready(function(){
	jQuery.loadState();
  jQuery('#printfonttype').selectbox({
    className: "jsb", replaceInvisible: true 
  }).change(function() {
    jQuery.rule('body, tt { font-family: ' + jQuery(this).val() + '; }').appendTo('style');
  });
  jQuery('#printfontsize').selectbox({
    className: "jsb", replaceInvisible: true 
  }).change(function() {
    var size = parseInt(jQuery(this).val());
    jQuery.rule('body, tt, .paragraph-numbering, #playlist .item_description, .collage-content .item_description { font-size: ' + size + 'pt; }').appendTo('style');
    jQuery.rule('#playlist h1, .collage-content > h1 { font-size: ' + (size + 6) + 'pt; }').appendTo('style');
    jQuery.rule('#playlist h3 { font-size:' + (size + 3) + 'pt; }').appendTo('style');
    jQuery('.print_border span').css('border-top-width', (size + 2) + 'pt');
    jQuery.rule('#playlist .details h2, .collage-content .info { font-size: ' + (size - 1) + 'pt; }').appendTo('style');
  });
});
