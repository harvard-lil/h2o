jQuery.extend({
	loadState: function() {
		jQuery('.collage-content').each(function(i, el) {
			var id = jQuery(el).data('id');
			var data = eval("collage_data_" + id);

			jQuery.each(data, function(i, e) {
        //id value is lost here - not sure why
				var id = jQuery(el).data('id');	

				if(i == 'highlights') {
					jQuery.each(e, function(a, h) {
            //jQuery.rule('#collage' + id + ' ' + a + ' { background-color: #' + h + '; text-decoration: underline; }').appendTo('style');
            jQuery.rule('#collage' + id + ' ' + a + ' { text-decoration: underline; }').appendTo('style');
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
    jQuery.rule('#playlist .details h2, .collage-content .info { font-size: ' + (size - 1) + 'pt; }').appendTo('style');
  });
});
