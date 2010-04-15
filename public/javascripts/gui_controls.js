function initDiscussionControls() {
    jQuery("[id^=button-discussion-decreasedate]").live('click', function() {
        var object_id = this.id.replace('button-discussion-decreasedate-', "");
        var container_id = jQuery('#container_id').text();
        var container_id_string = "";
        if (container_id) {
            container_id_string = "?container_id=" + container_id;
        }

        jQuery.ajax({
            type: 'post',
            url: '/rotisserie_discussions/' +object_id+ '/changestart',
            dataType: 'json',
            data: {
                'dayvalue': '-1'
            },
            success: function(data) {
                jQuery('#list_block').load('/rotisserie_discussions/block' + container_id_string, function() {
                    //initDiscussionControls();
                });
            }
        });
    });

    jQuery("[id^=button-discussion-increasedate]").live('click', function() {
        var object_id = this.id.replace('button-discussion-increasedate-', "");
        var container_id = jQuery('#container_id').text();
        var container_id_string = "";
        if (container_id) {
            container_id_string = "?container_id=" + container_id;
        }

        jQuery.ajax({
            type: 'post',
            url: '/rotisserie_discussions/' +object_id+ '/changestart',
            dataType: 'json',
            data: {
                'dayvalue': '1'
            },
            success: function(data) {
                jQuery('#list_block').load('/rotisserie_discussions/block' + container_id_string, function() {
                    //initDiscussionControls();
                });
            //jQuery('#rotisserie_discussion_startdate-' + object_id).text(data.start_date);
            //jQuery('#rotisserie_discussion_round-' + object_id).text(data.round);
            }
        });
    });


    jQuery("[id^=button-discussion-activate]").live('click', function() {
        var container_id = jQuery('#container_id').text();
        var container_id_string = "";
        if (container_id) {
            container_id_string = "?container_id=" + container_id;
        }

        var object_id = this.id.replace('button-discussion-activate-', "");

        jQuery.ajax({
            type: 'post',
            url: '/rotisserie_discussions/' +object_id+ '/activate',
            dataType: 'json',
            complete: function(data) {
                jQuery('#list_block').load('/rotisserie_discussions/block' + container_id_string, function() {
                    //initDiscussionControls();
                });}
        });
    });

    jQuery("[id^=button-discussion-notify]").live('click', function() {
        var object_id = this.id.replace('button-discussion-notify-', "");
        var container_id = jQuery('#container_id').text();
        var container_id_string = "";
        if (container_id) {
            container_id_string = "?container_id=" + container_id;
        }

        jQuery.ajax({
            type: 'post',
            url: '/rotisserie_discussions/' +object_id+ '/notify',
            dataType: 'json',
            complete: function(data) {
                jQuery('#list_block').load('/rotisserie_discussions/block' + container_id_string, function() {
                    //initDiscussionControls();
                });
            }
        });
    });
}
