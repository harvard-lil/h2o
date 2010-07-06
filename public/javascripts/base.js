jQuery(function() {
    jQuery("[name=object_accordian]").accordion({ active: false, collapsible: true });

    jQuery("[id^=object_role-]").live('change', function() {
        var object_id = this.id.replace('object_role-', "");

        jQuery.ajax({
            type: "post",
            dataType: 'json',
            url: '/base/update_role',
            data: {
                'object_id': object_id,
                'role_string': jQuery(this).val()
            }
        });
    });

    jQuery("[id^=object_visible-]").live('change', function() {
        var object_identifier = this.id.replace('object_visible-', "");

        jQuery.ajax({
            type: "post",
            dataType: 'json',
            url: '/base/update_visibility',
            data: {
                'object_identifier': object_identifier,
                'public_value': jQuery(this).val()
            }
        });
    });
    
});
