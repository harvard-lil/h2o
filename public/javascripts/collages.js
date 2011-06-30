var new_annotation_start = '';
var new_annotation_end = '';
var just_hidden = 0;
var layer_info = {};
var last_annotation = 0;
var highlight_history = {};

jQuery.extend({
	highlightHistoryAdd: function(id, aid, highlighted) {
		if(!highlight_history[aid]) {
			highlight_history[aid] = ['ffffff'];
		}
		if(highlighted) {
			highlight_history[aid].push(layer_info[id].hex);
		} else {
			var update = [];
			jQuery.each(highlight_history[aid], function(i, v) {
				if(layer_info[id].hex != v) {
					update.push(v);
				}
			});
			update.push(layer_info[id].hex);
			highlight_history[aid] = update;
		}
		var last = highlight_history[aid].length - 1;
		jQuery('tt.a' + aid).css('background', '#' + highlight_history[aid][last]);
	},
	highlightHistoryRemove: function(id, aid, highlighted) {
		if(highlighted) {
			highlight_history[aid].pop();
		} else {
			var update = [];
			jQuery.each(highlight_history[aid], function(i, v) {
				if(layer_info[id].hex != v) {
					update.push(v);
				}
			});
			highlight_history[aid] = update;
		}
		var last = highlight_history[aid].length - 1;
		jQuery('tt.a' + aid).css('background', '#' + highlight_history[aid][last]);
	},
	addCommas: function(str) {
		str += '';
		x = str.split('.');
		x1 = x[0];
		x2 = x.length > 1 ? '.' + x[1] : '';
		var rgx = /(\d+)(\d{3})/;
		while(rgx.test(x1)) {
			x1 = x1.replace(rgx, '$1' + ',' + '$2');
		}
		return x1 + x2;
	},
	recordCollageState: function(data) {
		jQuery.ajax({
			type: 'POST',
			cache: false,
			data: {
				v: data
			},
			url: jQuery.rootPath() + 'collages/' + jQuery('h2.collage-id').data('itemid') + '/save_readable_state',
			success: function(results){
				jQuery('#autosave').html('saved at ' + results.time).show().fadeOut(5000); 
			}
		});
	},
	listenToRecordCollageState: function() {
		setInterval(function(i) {
			var data = {};
			jQuery('.unlayered_start').each(function(i, el) {
				data['.unlayered_' + jQuery(el).attr('id').replace(/^t/, '')] = jQuery(el).css('display');	
			});
			jQuery('.unlayered-ellipsis').each(function(i, el) {
				data['#' + jQuery(el).attr('id')] = jQuery(el).css('display');	
			});
			jQuery('.annotation-ellipsis').each(function(i, el) {
				data['#' + jQuery(el).attr('id')] = jQuery(el).css('display');	
			});
			jQuery('.annotation-asterisk').each(function(i, el) {
				data['.a' + jQuery(el).data('id')] = jQuery(el).css('display');	
				data['#' + jQuery(el).attr('id')] = jQuery(el).css('display');
			});
			jQuery('.annotation-content').each(function(i, el) {
				if(jQuery(el).attr('id')) {
					data['#annotation-content-' + jQuery(el).attr('id').replace(/annotation-content-/, '')] = jQuery(el).css('display');	
				}
			});
			data.edit_mode = jQuery('#edit-show').html() == 'READ' ? true : false;
			if(JSON.stringify(data) != JSON.stringify(last_data)) {
				last_data = data;
				jQuery.recordCollageState(JSON.stringify(data));
			}
		}, 5000); 
	},
	loadState: function() {
		var total_words = jQuery('tt').size();
		var shown_words = total_words;
		jQuery.each(last_data, function(i, e) {
			if(i.match(/\.a/) && e != 'none') {
				jQuery(i).css('display', 'inline');
			} else if(i.match(/\.unlayered/) && e == 'none') {
				// if unlayered text default is hidden,
				// add wrapper nodes with arrow for collapsing text
				// here!
				jQuery(i).addClass('default-hidden').css('display', 'none');
			} else {
				jQuery(i).css('display', e);
			}
			if((i.match(/^\.unlayered/) || i.match(/^\.a/)) && e == 'none') {
				shown_words -= jQuery('tt' + i).size();
			}
		});
		jQuery('#word_count').html('Number of visible words: ' + jQuery.addCommas(shown_words) + ' out of ' + jQuery.addCommas(total_words));
		if(last_data.edit_mode && is_owner) {
			jQuery('#edit-show').html("READ");	
	 		jQuery.observeWords();
			jQuery('.details .edit-action').show();
			jQuery('.control-divider').css('display', 'inline-block');
			jQuery('article tt.a').addClass('edit_highlight');
		} else {
	 		jQuery.unObserveWords();
		}
		jQuery('article').css('opacity', 1.0);
	},
	addLayerToCookie: function(cookieName,layerId){
		var currentVals = jQuery.unserializeHash(jQuery.cookie(cookieName));
		currentVals[layerId] = 1;
		var cookieVal = jQuery.serializeHash(currentVals);
		jQuery.cookie(cookieName, cookieVal, {
			expires: 365
		});
	},

	submitAnnotation: function(){
		var collageId = jQuery('.collage-id').attr('id').split('-')[1];
		jQuery('#annotation-form form').ajaxSubmit({
			error: function(xhr){
				jQuery.hideGlobalSpinnerNode();
				jQuery('#new-annotation-error').show().append(xhr.responseText);
			},
			beforeSend: function(){
				jQuery.showGlobalSpinnerNode();
				jQuery('div.ajax-error').html('').hide();
				jQuery('#new-annotation-error').html('').hide();
			},
			success: function(response){
				jQuery.hideGlobalSpinnerNode();
				jQuery.cookie('layer-names', jQuery('#annotation_layer_list').val(), {
					expires: 365
				});
				jQuery('#annotation-form').dialog('close');
				document.location = jQuery.rootPath() + 'collages/' + collageId;
			}
		});
	},

	removeLayerFromCookie: function(cookieName,layerId){
		var currentVals = jQuery.unserializeHash(jQuery.cookie(cookieName));
		delete currentVals[layerId];
		var cookieVal = jQuery.serializeHash(currentVals);
		jQuery.cookie(cookieName,cookieVal,{
			expires: 365
		});
	},

	addAnnotationListeners: function(obj) {
	layer_id = 0;
	if(obj.layers.length) {
		layer_id = obj.layers[obj.layers.length - 1].id;
	}

	if(obj.layers.length > 0) {
			jQuery('#annotation-asterisk-' + obj.id).hoverIntent({
		 		over: function(e){
						jQuery.highlightHistoryAdd('l' + layer_id, obj.id, true);
					}, 
					timeout: 1000,
					out: function(e){
						jQuery.highlightHistoryRemove('l' + layer_id, obj.id, true);
					}
			});
	}

	jQuery('#annotation-ellipsis-' + obj.id).click(function(e) {
		jQuery('article tt.a' + obj.id + ', #annotation-control-' + obj.id + ',#annotation-asterisk-' + obj.id).show();
		jQuery(this).hide();
				e.preventDefault();
		});
	},

	toggleAnnotation: function(id) {
		if(jQuery('#annotation-content-' + id).css('display') == 'inline') {
			jQuery('#annotation-content-' + id).hide();
		} else {
			jQuery('#annotation-content-' + id).css('display', 'inline');
		}
	},

	annotationButton: function(annotationId){
		var collageId = jQuery('.collage-id').attr('id').split('-')[1];
		if(jQuery('#annotation-details-' + annotationId).length == 0){
			jQuery.ajax({
				type: 'GET',
				cache: false,
				url: jQuery.rootPath() + 'annotations/' + annotationId,
				beforeSend: function(){
					jQuery.showGlobalSpinnerNode();
					jQuery('div.ajax-error').html('').hide();
				},
				error: function(xhr){
					jQuery.hideGlobalSpinnerNode();
					jQuery('div.ajax-error').show().append(xhr.responseText);
				},
				success: function(html){
					// Set up the annotation node to be loaded into a dialog
					jQuery.hideGlobalSpinnerNode();
					var node = jQuery(html);
					jQuery('body').append(node);
					var dialog = jQuery('#annotation-details-' + annotationId).dialog({
						height: 500,
						title: 'Annotation Details',
						width: 600,
						//position: [e.clientX,e.clientY - 330],
						buttons: {
							Close: function(){
								jQuery(this).dialog('close');
							},
							Delete: function(){
								if(confirm('Are you sure?')){
									jQuery.ajax({
										cache: false,
										type: 'POST',
										data: {
											'_method': 'delete'
										},
										url: jQuery.rootPath() + 'annotations/destroy/' + annotationId,
										beforeSend: function(){
											jQuery.showGlobalSpinnerNode();
										},
										error: function(xhr){
											jQuery.hideGlobalSpinnerNode();
											jQuery('div.ajax-error').show().append(xhr.responseText);
										},
										success: function(response){
											jQuery('#annotation-details-' + annotationId).dialog('close');
											document.location = jQuery.rootPath() + 'collages/' + collageId;
										},
										complete: function(){
											jQuery('#please-wait').dialog('close');
										}
									});
								}
							},
							Edit: function(){
								jQuery(this).dialog('close');
								jQuery.ajax({
									type: 'GET',
									cache: false,
									url: jQuery.rootPath() + 'annotations/edit/' + annotationId,
									beforeSend: function(){
										jQuery.showGlobalSpinnerNode();
										jQuery('#new-annotation-error').html('').hide();
									},
									error: function(xhr){
										jQuery.hideGlobalSpinnerNode();
										jQuery('#new-annotation-error').show().append(xhr.responseText);
									},
									success: function(html){
										jQuery.hideGlobalSpinnerNode();
										jQuery('#annotation-form').html(html);
										jQuery.updateAnnotationPreview(collageId);
										jQuery('#annotation-form').dialog({
											bgiframe: true,
											minWidth: 950,
											width: 950,
											modal: true,
											title: 'Edit Annotation',
											buttons: {
												'Save': function(){
													jQuery.submitAnnotation();
												},
												Cancel: function(){
													jQuery('#new-annotation-error').html('').hide();
													jQuery(this).dialog('close');
												}
											}
										});
										jQuery("#annotation_annotation").markItUp(myTextileSettings);

										/*										jQuery(document).bind('keypress','ctrl+shift+k',
											function(e){
											alert('pressed!');
											jQuery.submitAnnotation();
											}
											); */
											jQuery('#annotation_layer_list').keypress(function(e){
												if(e.keyCode == '13'){
													e.preventDefault();
													jQuery.submitAnnotation();
												}
											});
									}
								});
							}
						}
					});

					jQuery('#annotation-tabs-' + annotationId).tabs();
					// Wipe out edit buttons if not owner.
					if(!is_owner) {
						jQuery('#annotation-details-' + annotationId).dialog('option','buttons',{
							Close: function(){
								jQuery(this).dialog('close');
							}
						});
					}
				}
			});
		} else {
			jQuery('#annotation-details-' + annotationId).dialog('open');
		}
	},

	initializeAnnotations: function(){
		jQuery('.annotation-asterisk').tipsy({ gravity: 'sw', fade: true });

		// This iterates through the annotations on this collage and emits the controls.
		var collageId = jQuery('.collage-id').attr('id').split('-')[1];
		jQuery.ajax({
			type: 'GET',
			url: jQuery.rootPath() + 'collages/annotations/' + collageId,
			dataType: 'json',
			cache: false,
			beforeSend: function(){
				jQuery.showGlobalSpinnerNode();
				jQuery('div.ajax-error').html('').hide();
			},
			success: function(json){
				//stash for later
				//jQuery('body').data('annotation_objects',json);
				jQuery(json).each(function(){
					/* var activeId = false;
					if(window.location.hash){
						activeId = window.location.hash.split('#')[1];
					} */
					jQuery.addAnnotationListeners(this.annotation);
				});

				jQuery('.unlayered-ellipsis').click(function(e) {
					e.preventDefault();
					var id = jQuery(this).attr('id').replace(/^unlayered-ellipsis-/, '');
					jQuery('.unlayered_' + id).show();
					jQuery(this).hide();
				});
				jQuery.hideGlobalSpinnerNode();
			},
			complete: function(){
				jQuery('#please-wait').dialog('close');
			},
			error: function(xhr){
				jQuery.hideGlobalSpinnerNode();
				jQuery('div.ajax-error').show().append(xhr.responseText);
			}

		});
	},

	observeLayers: function(){
		var collageId = jQuery('.collage-id').attr('id').split('-')[1];
		jQuery('.layer-control').click(function(e){
			var layerId = jQuery(this).attr('id').split('-')[2];
			if(jQuery('#layer-checkbox-' + layerId).is(':checked')){
				// Set the name and id of the active layers.
				jQuery.addLayerToCookie('active-layer-ids',layerId);
			} else {
				jQuery.removeLayerFromCookie('active-layer-ids',layerId);
			}
		});
	},

	updateAnnotationPreview: function(collageId){
		jQuery("#annotation_annotation").observeField(5,function(){
			jQuery.ajax({
				cache: false,
				type: 'POST',
				url: jQuery.rootPath() + 'annotations/annotation_preview',
				data: {
					preview: jQuery('#annotation_annotation').val(),
					collage_id: collageId
				},
				success: function(html){
					jQuery('#annotation_preview').html(html);
				}
			});
		});
	},

	wordEvent: function(e){
		var el = jQuery(this);
		if(e.type == 'mouseover'){
			el.addClass('annotation_start_highlight');
		}
		if(e.type == 'mouseout'){
			el.removeClass('annotation_start_highlight');
		} else if(e.type == 'click'){
			e.preventDefault();
			if(new_annotation_start != '') {
				new_annotation_end = el.attr('id');
				var collageId = jQuery('.collage-id').attr('id').split('-')[1];
				jQuery('#annotation-form').dialog({
					bgiframe: true,
					autoOpen: false,
					minWidth: 950,
					width: 950,
					modal: true,
					title: 'New Annotation',
					buttons: {
						'Save': function(){
							jQuery.submitAnnotation();
						},
						'Cancel': function(){
							jQuery('#new-annotation-error').html('').hide();
							el.dialog('close');
						}
					}
				});
				jQuery.ajax({
					type: 'GET',
					url: jQuery.rootPath() + 'annotations/new',
					data: {
						collage_id: collageId,
						annotation_start: new_annotation_start,
						annotation_end: new_annotation_end
					},
					cache: false,
					beforeSend: function(){
						jQuery.showGlobalSpinnerNode();
						jQuery('div.ajax-error').html('').hide();
					},
					success: function(html){
						jQuery.hideGlobalSpinnerNode();
						jQuery('#annotation-form').html(html);
						jQuery('#annotation-form').dialog('open');
						jQuery("#annotation_annotation").markItUp(myTextileSettings);
							jQuery('#annotation_layer_list').keypress(function(e){
								if(e.keyCode == '13'){
									e.preventDefault();
									jQuery.submitAnnotation();
								}
							});
							jQuery.updateAnnotationPreview(collageId);
							if(jQuery('#annotation_layer_list').val() == ''){
								jQuery('#annotation_layer_list').val(jQuery.cookie('layer-names'));
							}
					},
					error: function(xhr){
						jQuery.hideGlobalSpinnerNode();
						jQuery('div.ajax-error').show().append(xhr.responseText);
					}
				});

				jQuery("#tooltip").fadeOut();
				new_annotation_start = '';
				new_annotation_end = '';
			} else {
				var pos = el.position();
				jQuery("#tooltip").css({ left: pos.left - 100 + el.width()/2, top: pos.top + 100 }).fadeIn();
				new_annotation_start = el.attr('id');
			}
		}
	},

	observeWords: function(){
		// This is a significant burden in that it binds to every "word node" on the page, so running it must
		// align with the rights a user has to this collage, otherwise we're just wasting cpu cycles. Also
		// the controller enforces privs - so feel free to fiddle with the DOM, it won't get you anywhere.
		// jQuery('tt:visible') as a query is much less efficient - unfortunately.

		if(is_owner) {
			jQuery('tt').unbind('mouseover mouseout click').bind('mouseover mouseout click', jQuery.wordEvent);
			jQuery('.annotation-content').hide();
			jQuery('.annotation-asterisk, .control-divider').unbind('click').click(function(e) {
				e.preventDefault();
				jQuery.annotationButton(jQuery(this).data('id'));
			});
		}
	},

	unObserveWords: function() {
		jQuery('tt').unbind('mouseover mouseout click');
		jQuery('.ann-details').hide();
		jQuery('.annotation-asterisk').unbind('click').click(function(e) {	
			e.preventDefault();
			jQuery.toggleAnnotation(jQuery(this).data('id'));
		});
	}

});

jQuery(document).ready(function(){
	if(jQuery('.collage-id').length > 0){
		jQuery('#cancel-annotation').click(function(e){
			e.preventDefault();
			jQuery("#tooltip").hide();
			new_annotation_start = '';
			new_annotation_end = '';
 		});

		jQuery.initializeAnnotations();

		jQuery('#full_text').click(function(e) {
			e.preventDefault();
			jQuery('article tt').show();
			jQuery('.annotation-ellipsis').hide();
			jQuery('#layers a strong').html('HIDE');
			jQuery('#layers .shown').removeClass('shown');

			jQuery('article .unlayered').show();
			jQuery('article .unlayered-ellipsis').hide();
		});

		jQuery('#hide_show_unlayered').click(function(e) {
			e.preventDefault();
			jQuery.showGlobalSpinnerNode();
			var el = jQuery(this);
			el.toggleClass('shown');
			if(el.find('strong').html() == 'SHOW') {
				jQuery('article .unlayered').show();
				jQuery('article .unlayered-ellipsis').hide();
				el.find('strong').html('HIDE');
			} else {
				jQuery('article .unlayered').hide();
				jQuery('article .unlayered-ellipsis').show();
				el.find('strong').html('SHOW');
			}
			jQuery.hideGlobalSpinnerNode();
		});

		/* TODO: Possibly add some abstraction here */
		jQuery('#hide_show_annotations').click(function(e) {
			e.preventDefault();
			jQuery.showGlobalSpinnerNode();

			var el = jQuery(this);
			el.toggleClass('shown');
			if(el.find('strong').html() == 'SHOW') {
				jQuery('.annotation-content').show();
				el.find('strong').html('HIDE');
			} else {
				jQuery('.annotation-content').hide();
				el.find('strong').html('SHOW');
			}
			jQuery.hideGlobalSpinnerNode();
		});

		jQuery('#layers .hide_show').click(function(e) {
			e.preventDefault();
			jQuery.showGlobalSpinnerNode();

			var el = jQuery(this);
			var layer_id = el.parent().data('id');
			//Note: Toggle here was very slow 
			if(el.find('strong').html() == 'SHOW') {
				el.find('strong').html('HIDE');
				jQuery('article .' + layer_id + ',.ann-annotation-' + layer_id).show();
				jQuery('.annotation-ellipsis-' + layer_id).hide();
			} else {
				el.find('strong').html('SHOW');
				jQuery('article .' + layer_id + ',.ann-annotation-' + layer_id).hide();
				jQuery('.annotation-ellipsis-' + layer_id).show();
			}
			jQuery.hideGlobalSpinnerNode();
		});

		jQuery('#layers .link-o').click(function(e) {
			e.preventDefault();
			var el = jQuery(this);
			var id = el.parent().data('id');
			if(el.hasClass('highlighted')) {
				el.siblings('.hide_show').find('strong').html('HIDE');
				jQuery('article .' + id + ',.ann-annotation-' + id).show();
				jQuery('.annotation-ellipsis-' + id).hide();
				jQuery('.annotation-ellipsis-' + id).each (function(i, el) {
					jQuery.highlightHistoryRemove(id, jQuery(el).data('id'), false);
				});
				el.removeClass('highlighted').html('HIGHLIGHT');
			} else {
				el.siblings('.hide_show').find('strong').html('HIDE');
				jQuery('article .' + id + ',.ann-annotation-' + id).show();
				jQuery('.annotation-ellipsis-' + id).hide();
				jQuery('.annotation-ellipsis-' + id).each (function(i, el) {
					jQuery.highlightHistoryAdd(id, jQuery(el).data('id'), false);
				});
				el.addClass('highlighted').html('UNHIGHLIGHT');
			}
		});
	
		jQuery("#edit-show").click(function(e) {
			e.preventDefault();
			var el = jQuery(this);
			if(el.html() == 'READ') {
				el.html("EDIT");	
		 		jQuery.unObserveWords();
				jQuery('.details .edit-action, .control-divider').hide();
				jQuery('article tt.a').removeClass('edit_highlight');
			} else {
				el.html("READ");	
		 		jQuery.observeWords();
				jQuery('.details .edit-action').show();
				jQuery('.control-divider').css('display', 'inline-block');
				jQuery('article tt.a').addClass('edit_highlight');
			}
			el.toggleClass('editing');
		});
	
		jQuery('#layers li').each(function(i, el) {
			layer_info[jQuery(el).data('id')] = {
				'hex' : jQuery(el).data('hex'),
				'name' : jQuery(el).data('name')
			};
			jQuery('a.annotation-control-' + jQuery(el).data('id')).css('background', '#' + jQuery(el).data('hex'));
			jQuery(el).find('.link-o').css('background', '#' + jQuery(el).data('hex'));
		});
	
		jQuery("#collage .description .buttons ul .btn-a span").parent().click(function() { 
			jQuery('.tools-popup').css({ 'top': 25 }).toggle();
			jQuery(this).toggleClass("btn-a-active");
			return false;
		});

		jQuery('#collage-stats').click(function() {
			jQuery(this).toggleClass("active");
			jQuery('#collage-stats-popup').toggle();
			return false;
		});

		if(is_owner) {
			jQuery.listenToRecordCollageState();
		}
		jQuery.loadState();
	}
});
