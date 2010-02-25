/* 
 * jQuery related to form creation and submission
 */

jQuery(function() {

    initButtons();

    jQuery("#dialog-new").dialog({
        bgiframe: true,
        autoOpen: false,
        minWidth: 400,
        width: 400,
        modal: true,
        buttons: {
            'Create': function() {
                jQuery('#new_rotisserie_instance').validate({
                    //debug: true,
                    rules: {
                        "rotisserie_instance[title]": {
                            required: true
                        },
                        "rotisserie_instance[output]": {
                            required: true
                        }
                    },
                    messages: {
                        "rotisserie_instance[title]": "A title is required",
                        "rotisserie_instance[output]": "Please enter some text that will be displayed to the user"
                    },
                    submitHandler: function(form) {
                        jQuery(form).ajaxSubmit(form_options);
                        jQuery("#dialog-new").dialog('close');
                        jQuery('#rotisserie_instances_block').html("<img src='/images/elements/ajax-loader.gif' />");
                        jQuery('#rotisserie_instances_block').load('/rotisserie_instances/block', function() {
                            initButtons();
                        });
                    },
                    errorClass: "error",
                    errorElement: "div",
                    errorPlacement:  function(error, element) {
                        error.appendTo(element.parent("li").next("li") );
                    }
                });
                jQuery('#new_rotisserie_instance').submit();

            
            },
            'Cancel': function() {
                jQuery("#dialog-new").dialog('close');
            }
        }
    });

    jQuery("#dialog-edit").dialog({
        bgiframe: true,
        autoOpen: false,
        minWidth: 400,
        width: 400,
        modal: true,
        buttons: {
            'Update': function() {
                jQuery('[id^=edit_rotisserie_instance]').validate({
                    //debug: true,
                    rules: {
                        "rotisserie_instance[title]": {
                            required: true
                        },
                        "rotisserie_instance[output]": {
                            required: true
                        }
                    },
                    messages: {
                        "rotisserie_instance[title]": "A title is required",
                        "rotisserie_instance[output]": "Please enter some text that will be displayed to the user"
                    },
                    submitHandler: function(form) {
                        jQuery(form).ajaxSubmit(form_options);
                        jQuery("#dialog-edit").dialog('close');
                        jQuery('#rotisserie_instances_block').html("<img src='/images/elements/ajax-loader.gif' />");
                        jQuery('#rotisserie_instances_block').load('/rotisserie_instances/block', function() {
                            initButtons();
                        });
                    },
                    errorClass: "error",
                    errorElement: "div",
                    errorPlacement:  function(error, element) {
                        error.appendTo(element.parent("li").next("li") );
                    }
                });
                jQuery('[id^=edit_rotisserie_instance]').submit();
            },
            'Cancel': function() {
                jQuery(this).dialog('close');
            }
        }
    });
    
    jQuery("#dialog-delete").dialog({
        bgiframe: true,
        autoOpen: false,
        minWidth: 400,
        width: 400,
        modal: true,
        buttons: {
            'Delete': function() {
                jQuery('#delete_rotisserie_instance').ajaxSubmit(form_options);
                jQuery('#delete_rotisserie_instance').submit(function() {
                    return false;
                });
                jQuery(this).dialog('close');
                jQuery('#rotisserie_instances_block').html("<img src='/images/elements/ajax-loader.gif' />");
                jQuery('#rotisserie_instances_block').load('/rotisserie_instances/block', function() {
                    initButtons();
                });
            },
            'Cancel': function() {
                jQuery(this).dialog('close');
            }
        }
    });





    var form_options = {
        //target: '#error_block'  // target element(s) to be updated with server response
        //dataType: 'script'
        //beforeSubmit:  showRequest,  // pre-submit callback
        //success:  function(data) { jQuery('#error_block').html(data);}
        //error: showResponse
        error: function(XMLHttpRequest, textStatus, errorThrown) {
            jQuery('#error_block').html(XMLHttpRequest.responseText);
        }

    // other available options:
    //url:       url         // override for form's 'action' attribute
    //type:      type        // 'get' or 'post', override for form's 'method' attribute
    //dataType:  null        // 'xml', 'script', or 'json' (expected server response type)
    //clearForm: true        // clear all form fields after successful submit
    //resetForm: true        // reset the form after successful submit

    // $.ajax options can be used here too, for example:
    //timeout:   3000
    }

    .hover(
        function(){
            jQuery(this).addClass("ui-state-hover");
        },
        function(){
            jQuery(this).removeClass("ui-state-hover");
        }
        ).mousedown(function(){
        jQuery(this).addClass("ui-state-active");
    })

    .mouseup(function(){
        jQuery(this).removeClass("ui-state-active");
    });

});

function initButtons() {
    
    // Spawn dialog when button is clicked
    jQuery('#create-instance').click(function() {
        jQuery('#dialog-new').dialog('open');
        jQuery('#dialog-new').html("<img src='/images/elements/ajax-loader.gif' />");
        jQuery('#dialog-new').load('/rotisserie_instances/new');
    });

    jQuery('[name=button-edit]').click(function() {
        var edit_id = this.id.replace('button-edit-', "");
        jQuery('#dialog-edit').dialog('open');
        jQuery('#dialog-edit').html("<img src='/images/elements/ajax-loader.gif' />");
        jQuery('#dialog-edit').load('/rotisserie_instances/' + edit_id + '/edit');
    });

    jQuery('[name=button-delete]').click(function() {
        var destroy_id = this.id.replace('button-delete-', "");
        jQuery('#dialog-delete').dialog('open');
        jQuery('#dialog-delete').html("<img src='/images/elements/ajax-loader.gif' />");
        jQuery('#dialog-delete').load('/rotisserie_instances/' + destroy_id + '/delete');
    });

}