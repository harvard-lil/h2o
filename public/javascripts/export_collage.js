jQuery.extend({
	loadState: function() {
		console.log(last_data);
		jQuery.each(last_data, function(i, e) {
			if(i.match(/\.a/) && e != 'none') {
				jQuery(i).css('display', 'inline');
			} else if(i.match(/\.unlayered/)) {
				if(e == 'none') {
					// if unlayered text default is hidden,
					// add wrapper nodes with arrow for collapsing text
					// here!
					jQuery(i).addClass('default-hidden').css('display', 'none');
				} else {
					jQuery(i).css('display', 'inline');
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
