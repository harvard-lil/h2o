// jQuery related to form creation and submission

jQuery(function() {

    initButtonGroup();


    objectDialog('#dialog-instance-new', '#new_rotisserie_instance', rules_instance, messages_instance, 'rotisserie_instances', form_options);
    objectDialog('#dialog-instance-edit', '[id^=edit_rotisserie_instance]', rules_instance, messages_instance, 'rotisserie_instances', form_options);
    
    objectConfirm('#dialog-instance-delete', '#delete_rotisserie_instance', 'rotisserie_instances', form_options);

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
    };



});

var rules_instance = {
    "rotisserie_instance[title]": {
        required: true
    },
    "rotisserie_instance[output]": {
        required: true
    }
};

var messages_instance = {
    "rotisserie_instance[title]": "A title is required",
    "rotisserie_instance[output]": "Please enter some text that will be displayed to the user"
};



function initButtonGroup() {
    
    // Spawn dialog when button is clicked
    initButton('button-instance-create', '#button-instance-create', '#dialog-instance-new', 'rotisserie_instances', 'new');
    initButton('button-instance-edit', '[name=button-instance-edit]', '#dialog-instance-edit', 'rotisserie_instances', 'edit');
    initButton('button-instance-delete', '[name=button-instance-delete]', '#dialog-instance-delete', 'rotisserie_instances', 'delete');

}

function initButton(button_name, button_selector, dialog_id, controller_name, action) {
    jQuery(button_selector).click(function() {
        if (action != 'new') {
            var object_id = this.id.replace(button_name + '-', "");
        }
        jQuery(dialog_id).dialog('open');
        jQuery(dialog_id).html("<img src='/images/elements/ajax-loader.gif' />");
        if (action == 'new') {
            jQuery(dialog_id).load('/'+ controller_name + '/new');
        } else {
            jQuery(dialog_id).load('/'+ controller_name + '/' + object_id + '/' + action);
        }
    });
}

/*
 dialog_id e.g.  '#dialog-new' - jQuery selector
 form_id e.g.  '#new_rotisserie_instance' - jQuery selector
 */

function objectDialog(dialog_id, form_id, rules_block, messages_block, controller_name, form_options) {
    
    jQuery(dialog_id).dialog({
        bgiframe: true,
        autoOpen: false,
        minWidth: 400,
        width: 400,
        modal: true,
        buttons: {
            'Submit': function() {
                var dialogObject = this;
                jQuery(form_id).validate({
                    //debug: true,
                    rules: rules_block,
                    messages: messages_block,
                    submitHandler: function(form) {
                        jQuery(form).ajaxSubmit(form_options);
                        jQuery(dialogObject).dialog('close');
                        jQuery('#list_block').load('/' + controller_name + '/block', function() {
                            initButtonGroup();
                        });

                    },
                    errorClass: "error",
                    errorElement: "div",
                    errorPlacement:  function(error, element) {
                        error.appendTo(element.parent("li").next("li") );
                    }
                });
                jQuery(form_id).submit();


            },
            'Cancel': function() {
                jQuery(this).dialog('close');
            }
        }
    });

}

function objectConfirm(dialog_id, form_id, controller_name, form_options) {

    jQuery(dialog_id).dialog({
        bgiframe: true,
        autoOpen: false,
        minWidth: 400,
        width: 400,
        modal: true,
        buttons: {
            'Yes': function() {
                jQuery(form_id).ajaxSubmit(form_options);
                jQuery(form_id).submit(function() {
                    return false;
                });
                jQuery(this).dialog('close');
                jQuery('#list_block').load('/' + controller_name + '/block', function() {
                    initButtonGroup();
                });
            },
            'No': function() {
                jQuery(this).dialog('close');
            }
        }
    });

}
