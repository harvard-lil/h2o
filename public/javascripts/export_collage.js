var color_map = {
	'ffcd00' : 'ccc',
	'ff999a' : 'aaa',
	'bdec68' : 'ddd' 
};



jQuery.extend({
	loadState: function() {
		jQuery.each(last_data, function(i, e) {
			if(i == 'highlights') {
				jQuery.each(e, function(a, h) {
					jQuery(a).css('background-color', '#' + color_map[h]);
				});
			} else if(i.match(/\.a/) && e != 'none') {
				jQuery(i).css('display', 'inline');
			} else if(i.match(/\.unlayered/)) {
				if(e == 'none') {
					// if unlayered text default is hidden,
					// add wrapper nodes with arrow for collapsing text
					// here!
					jQuery(i).addClass('default-hidden').css('display', 'none');
				} else {
					jQuery('tt' + i).css('display', 'inline');
					jQuery('p' + i + ', center' + i).css('display', 'block');
					//Remove unlayered collapse links here
					var id = i.match(/\d+/).toString();
					jQuery('.unlayered-control-' + id).remove();
				}
			} else {
				jQuery(i).css('display', e);
			}
		});
		jQuery('article').css('opacity', 1.0);
	}
});

jQuery(document).ready(function(){
	jQuery.loadState();
});
