jQuery.extend({
    showGlobalSpinnerNode: function() {
		jQuery('#spinner').show();
	},
	hideGlobalSpinnerNode: function() {
		jQuery('#spinner').hide();
	},
	showMajorError: function(xhr) {
		//empty for now
	},

    observeDestroyControls: function(){
	  	jQuery('.delete-action').live('click', function(e){
			var item_id;
			if(jQuery("#results")) {
				item_id = jQuery(this).closest(".listitem").data("itemid");
			} else {
				item_id = jQuery(".singleitem").data("itemid");
			}
        	var destroyUrl = jQuery(this).attr('href');
        	e.preventDefault();
        	var confirmNode = jQuery('<div><p>Are you sure you want to delete this item?</p></div>');
        	jQuery(confirmNode).dialog({
          		modal: true,
				close: function() {
					jQuery(confirmNode).remove();
				},
          		buttons: {
					Yes: function() {
              			jQuery.ajax({
                			cache: false,
                			type: 'POST',
                			url: destroyUrl,
                			dataType: 'JSON',
                			data: {'_method': 'delete'},
                			beforeSend: function(){
                  				jQuery.showGlobalSpinnerNode();
                			},
                			error: function(xhr){
                  				jQuery.hideGlobalSpinnerNode();
                  				//jQuery.showMajorError(xhr); 
                			},
                			success: function(){
								jQuery(".listitem" + item_id).animate({ opacity: 0.0, height: 0 }, 500, function() {
									jQuery(".listitem" + item_id).remove();
								});
                  				jQuery.hideGlobalSpinnerNode();
                  				jQuery(confirmNode).remove();
							}
              			});
            		},
          			No: function(){
            			jQuery(confirmNode).remove();
          			}
				}
        	}).dialog('open');
		});
    },
    observeRemixControls: function(){
	  	jQuery('.remix-action,.edit-action,.new-action,.bookmark-action').live('click', function(e){
			var item_id;
			if(jQuery("#results")) {
				item_id = jQuery(this).closest(".listitem").data("itemid");
			} else {
				item_id = jQuery(".singleitem").data("itemid");
			}
        	var actionUrl = jQuery(this).attr('href');
			var actionText = jQuery(this).html();
        	e.preventDefault();
			jQuery.ajax({
				cache: false,
				url: actionUrl,
				beforeSend: function() {
                  	jQuery.showGlobalSpinnerNode();
				},
				success: function(html) {
                  	jQuery.hideGlobalSpinnerNode();
					var newItemNode = jQuery('<div id="generic-node"></div>').html(html);
					jQuery(newItemNode).dialog({
						title: actionText,
						modal: true,
						width: 'auto',
						height: 'auto',
						close: function() {
							jQuery(newItemNode).remove();
						},
						buttons: {
							Submit: function() {
								jQuery.submitGenericNode();
							},
							Close: function() {
								jQuery(newItemNode).remove();
							}
						}
					}).dialog('open');
				},
				error: function(xhr, textStatus, errorThrown) {
                  	jQuery.hideGlobalSpinnerNode();
				}
			});
		});
	},
	submitGenericNode: function() {
		jQuery('#generic-node').find('form').ajaxSubmit({
			dataType: "JSON",
			beforeSend: function() {
				jQuery.showGlobalSpinnerNode();
			},
			success: function(data) {
				document.location.href = jQuery.rootPath() + jQuery.classType() + '/' + data.id;
			},
			error: function(xhr) {
				jQuery.hideGlobalSpinnerNode();
				//message some error
			}
		});
	}
});
	
