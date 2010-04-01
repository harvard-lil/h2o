// jQuery related to form creation and submission

jQuery(function() {

    initGroup();

    var form_options = {
        //target: '#error_block'  // target element(s) to be updated with server response
        //dataType: 'script'
        //beforeSubmit:  showRequest,  // pre-submit callback
        //success:  function(data) {  },
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

    //instance dialogs
    objectDialog('#dialog-instance-new', '#new_rotisserie_instance', rules_instance, messages_instance, 'rotisserie_instances');
    objectDialog('#dialog-instance-edit', '[id^=edit_rotisserie_instance]', rules_instance, messages_instance, 'rotisserie_instances');

    objectConfirm('#dialog-instance-delete', '#delete_rotisserie_instance', 'rotisserie_instances');

    //discussion dialogs
    objectDialog('#dialog-discussion-new', '#new_rotisserie_discussion', rules_discussion, messages_discussion, 'rotisserie_discussions');
    objectDialog('#dialog-discussion-edit', '[id^=edit_rotisserie_discussion]', rules_discussion, messages_discussion, 'rotisserie_discussions');

    objectConfirm('#dialog-discussion-delete', '#delete_rotisserie_discussion', 'rotisserie_discussions');

    //post dialogs
    objectDialog('#dialog-post-reply', '#new_rotisserie_reply', rules_post, messages_post, 'rotisserie_posts');
    objectDialog('#dialog-post-new', '#new_rotisserie_post', rules_post, messages_post, 'rotisserie_posts');
    objectDialog('#dialog-post-edit', '[id^=edit_rotisserie_post]', rules_post, messages_post, 'rotisserie_posts');

    objectConfirm('#dialog-post-delete', '#delete_rotisserie_post', 'rotisserie_posts');

});

// Arrays of validation rules and messages

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

var rules_discussion = {
    "rotisserie_discussion[title]": {
        required: true
    },
    "rotisserie_discussion[output]": {
        required: true
    },
    "rotisserie_discussion[round_length]": {
        required: true
    },
    "rotisserie_discussion[final_round]": {
        required: true
    },
    "start_date": {
        required: true
    }
};

var messages_discussion = {
    "rotisserie_discussion[title]": "A title is required",
    "rotisserie_discussion[output]": "Please enter some text that will be displayed to the user",
    "rotisserie_discussion[round_length]": "Please enter a minimum number of rounds",
    "rotisserie_discussion[final_round]": "Please enter the final round",
    "start_date": "Please enter a starting date"
};

var rules_post = {
    "rotisserie_post[title]": {
        required: true
    },
    "rotisserie_post[output]": {
        required: true
    }
};

var messages_post = {
    "rotisserie_post[title]": "A title is required",
    "rotisserie_post[output]": "Please enter your response"
};

function initGroup() {
    
    // Spawn instance dialog when button is clicked
    initButton('button-instance-create', '#button-instance-create', '#dialog-instance-new', 'rotisserie_instances', 'new');
    initButton('button-instance-edit', '[name=button-instance-edit]', '#dialog-instance-edit', 'rotisserie_instances', 'edit');
    initButton('button-instance-delete', '[name=button-instance-delete]', '#dialog-instance-delete', 'rotisserie_instances', 'delete');

    // Spawn discussion dialog when button is clicked
    initButton('button-discussion-create', '[name=button-discussion-create]', '#dialog-discussion-new', 'rotisserie_discussions', 'new');
    initButton('button-discussion-edit', '[name=button-discussion-edit]', '#dialog-discussion-edit', 'rotisserie_discussions', 'edit');
    initButton('button-discussion-delete', '[name=button-discussion-delete]', '#dialog-discussion-delete', 'rotisserie_discussions', 'delete');

    // Spawn discussion dialog when button is clicked
    initButton('button-post-reply', '[name=button-post-reply]', '#dialog-post-reply', 'rotisserie_posts', 'reply');
    initButton('button-post-create', '[name=button-post-create]', '#dialog-post-new', 'rotisserie_posts', 'new');
    initButton('button-post-edit', '[name=button-post-edit]', '#dialog-post-edit', 'rotisserie_posts', 'edit');
    initButton('button-post-delete', '[name=button-post-delete]', '#dialog-post-delete', 'rotisserie_posts', 'delete');



}

function initButton(button_name, button_selector, dialog_id, controller_name, action) {
    jQuery(button_selector).click(function() {
        var object_id = this.id.replace(button_name + '-', "");
        jQuery(dialog_id).dialog('open');
        jQuery(dialog_id).html("<img src='/images/elements/ajax-loader.gif' />");
        if (action == 'new') {
            jQuery(dialog_id).load('/'+ controller_name + '/new', {
                container_id: object_id
            });
        } else if (action == 'reply') {
            jQuery(dialog_id).load('/'+ controller_name + '/new', {
                parent_id: object_id,
                container_id: jQuery('#container_id').text()
            });
        } else {
            jQuery(dialog_id).load('/'+ controller_name + '/' + object_id + '/' + action);
        }
    });
}

/*
 dialog_id e.g.  '#dialog-new' - jQuery selector
 form_id e.g.  '#new_rotisserie_instance' - jQuery selector
 */

function objectDialog(dialog_id, form_id, rules_block, messages_block, controller_name) {

    var options = {
        success:  function() {
            var container_id = jQuery('#container_id').text();
            var container_id_string = "";
            if (container_id) {
                container_id_string = "?container_id=" + container_id;
            }
            
            jQuery(dialog_id).dialog('close');
            jQuery('#list_block').load('/' + controller_name + '/block' + container_id_string, function() {
                initGroup();
            });
        },
        error: function(XMLHttpRequest, textStatus, errorThrown) {
            jQuery('#error_block').html(XMLHttpRequest.responseText);
        }
    };
    
    jQuery(dialog_id).dialog({
        bgiframe: true,
        autoOpen: false,
        minWidth: 400,
        height: "auto",
        position: "center",
        width: 500,
        modal: true,
        buttons: {
            'Submit': function() {
                var dialogObject = this;
                jQuery(form_id).validate({
                    //debug: true,
                    rules: rules_block,
                    messages: messages_block,
                    submitHandler: function(form) {
                        jQuery(form).ajaxSubmit(options);
                    //jQuery(dialogObject).dialog('close');
                    //jQuery('#list_block').load('/' + controller_name + '/block', function() {initButtonGroup();});

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

function objectConfirm(dialog_id, form_id, controller_name) {

    var options = {
        success:  function(responseText, statusText, xhr, formElement) {
            var container_id = jQuery('#container_id').text();
            var container_id_string = "";
            if (container_id) {
                container_id_string = "?container_id=" + container_id;
            }

            jQuery(dialog_id).dialog('close');
            jQuery('#list_block').load('/' + controller_name + '/block' + container_id_string, function() {
                initGroup();
            });
        },
        error: function(XMLHttpRequest, textStatus, errorThrown) {
            jQuery('#error_block').html(XMLHttpRequest.responseText);
        }
    };

    jQuery(dialog_id).dialog({
        bgiframe: true,
        autoOpen: false,
        minWidth: 400,
        width: 400,
        modal: true,
        buttons: {
            'Yes': function() {
                jQuery(form_id).ajaxSubmit(options);
                jQuery(form_id).submit(function() {
                    return false;
                });
            },
            'No': function() {
                jQuery(this).dialog('close');
            }
        }
    });

}
