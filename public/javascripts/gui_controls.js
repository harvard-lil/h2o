function initDiscussionControls() {
    jQuery("[id^=button-discussion-decreasedate]").click(function() {
        var object_id = this.id.replace('button-discussion-decreasedate-', "");

        jQuery.ajax({
            type: 'post',
            url: '/rotisserie_discussions/' +object_id+ '/changestart',
            dataType: 'json',
            data: {'dayvalue': '-1'},
            success: function(data) {
                jQuery('#rotisserie_discussion_startdate-' + object_id).text(data.start_date);
                jQuery('#rotisserie_discussion_round-' + object_id).text(data.round);
            }
        });
    });

    jQuery("[id^=button-discussion-increasedate]").click(function() {
        var object_id = this.id.replace('button-discussion-increasedate-', "");

        jQuery.ajax({
            type: 'post',
            url: '/rotisserie_discussions/' +object_id+ '/changestart',
            dataType: 'json',
            data: {'dayvalue': '1'},
            success: function(data) {
                jQuery('#rotisserie_discussion_startdate-' + object_id).text(data.start_date);
                jQuery('#rotisserie_discussion_round-' + object_id).text(data.round);
            }
        });
    });


    jQuery("[id^=button-discussion-activate]").click(function() {
        var object_id = this.id.replace('button-discussion-activate-', "");

        jQuery.ajax({
            type: 'post',
            url: '/rotisserie_discussions/' +object_id+ '/activate',
            dataType: 'json'
        });
    });
}
