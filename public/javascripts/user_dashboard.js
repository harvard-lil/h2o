jQuery.extend({
	updated_permissions: function(data) {
		jQuery('.extra' + data.id).append(jQuery('<span>Updated!</span>'));
		jQuery.hideGlobalSpinnerNode();
		jQuery('#generic-node').dialog('close');
		jQuery('.extra' + data.id + ' span').fadeOut(4000, function() { jQuery(this).remove(); });
	},
	observeCaseApproval: function() {
		jQuery('.approve-action').live('click', function(e) {
			e.preventDefault();
	
			var approveUrl = jQuery(this).attr('href');
			var item_id = approveUrl.match(/[0-9]+/).toString();
			jQuery.ajax({
				cache: false,
				type: 'POST',
				url: approveUrl,
				dataType: 'JSON',
				data: {},
				beforeSend: function(){
					jQuery.showGlobalSpinnerNode();
				},
				error: function(xhr){
					jQuery.hideGlobalSpinnerNode();
				},
				success: function(data){
					jQuery(".listitem" + item_id).animate({ opacity: 0.0, height: 0 }, 500, function() {
						jQuery(".listitem" + item_id).remove();
					});
					jQuery.hideGlobalSpinnerNode();
				}
			});
		});
	},
	observeCollectionActions: function() {
		jQuery('#lookup_submit').live('click', function(e) {
			e.preventDefault();
			var link = jQuery(this);
			var type = link.data('type');
			if(jQuery(this).hasClass('disabled')) {
				return false;
			}
			jQuery.ajax({
				type: 'GET',
				cache: false,
				url: jQuery(this).attr('href'),
				dataType: "JSON",
				data: {
					lookup: jQuery('#lookup').val()
				},
				beforeSend: function() {
					jQuery.showGlobalSpinnerNode();
					link.addClass('disabled');
				},
				error: function(xhr){
					jQuery.hideGlobalSpinnerNode();
					link.removeClass('disabled');
					jQuery('#lookup_results li').remove();
					var node = jQuery('<li>');
					node.append(jQuery('<span>Error: please try again.</span>'));
					jQuery('#lookup_results').append(node);
				},
				success: function(results){
					jQuery('#lookup_results li').remove();
					jQuery('#lookup').val('');
					if(results.items.length == 0) {
						var node = jQuery('<li>');
						node.append(jQuery('<span>Could not find any ' + type + 's.</span>'));
						jQuery('#lookup_results').append(node);
					}
					jQuery.each(results.items, function(i, el) {
						var node = jQuery('<li class="item' + el.id + '">');
						node.append(jQuery('<span>' + el.display + '</span>'));
						if(jQuery('#current_list .item' + el.id).length) {
							node.append(jQuery('<span> (already added)</span>'));
						} else {
							node.append(jQuery('<a data-type="' + type + '" data-id="' + el.id + '">').attr('href', '#').addClass('add_item').html('ADD'));
						}
						jQuery('#lookup_results').append(node);
					});
					jQuery.hideGlobalSpinnerNode();
					link.removeClass('disabled');
				}
			});
		});
		jQuery('.remove_item').live('click', function(e) {
			e.preventDefault();
			jQuery(this).parent().remove();
		});
		jQuery('.add_item').live('click', function(e) {
			e.preventDefault();
			var link = jQuery(this);
			var cloned = link.parent().clone();
			cloned.append(jQuery('<input type="hidden">').attr('name', 'user_collection[' + link.data('type') + '_ids][]').val(link.data('id')));
			cloned.find('.add_item').removeClass('add_item').addClass('remove_item').html('REMOVE');
			jQuery('#current_list').append(cloned);
			link.parent().remove();
		});
	},
	listResultsSpecial: function(url, region) {
		jQuery.ajax({
			type: 'GET',
			dataType: 'html',
			url: url,
			beforeSend: function(){
					 jQuery.showGlobalSpinnerNode();
				 },
				 error: function(xhr){
					 jQuery.hideGlobalSpinnerNode();
			},
			success: function(html){
				jQuery.address.value(url);
				jQuery.hideGlobalSpinnerNode();
				jQuery('#results_' + region).html(html);
				jQuery('#pagination_' + region).html(jQuery('#new_pagination').html());
				jQuery('#new_pagination').remove();
				jQuery.initializeBarcodes();
				jQuery.observeResultsHover();
			}
		});
	},
	observeSpecialPagination: function() {
		jQuery('.special_sort select').selectbox({
			className: "jsb", replaceInvisible: true 
		}).change(function() {
			var sort = jQuery(this).val();
			var region = jQuery(this).parent().parent().data('region');
			var url = document.location.pathname + '?ajax_region=' + region + '&sort=' + sort;
			jQuery.listResultsSpecial(url, region);
		});
		jQuery('.users_pagination a').live('click', function(e) {
			e.preventDefault();
			var href = jQuery(this).attr('href');
			var region = jQuery(this).parent().data('region');
			jQuery.listResultsSpecial(href, region);
		});
	}
});

jQuery(function() {
	jQuery.observeCaseApproval();
	jQuery.observeCollectionActions();
	jQuery.observeSpecialPagination();
});
