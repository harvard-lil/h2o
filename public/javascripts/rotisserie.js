

jQuery(function() {

    jQuery("#email_validate").live('click', function() {
        var container_id = jQuery('#container_id').text();

        jQuery.ajax({
            type: "post",
            dataType: 'json',
            url: '/rotisserie_instances/validate_email_csv',
            data: {
                'csv_string': jQuery("#csv-emails").val()
            },
            success: function(data, textStatus, XMLHttpRequest){
                jQuery("#csv-preview").load("/rotisserie_instances/display_validation",{
                    'good_array': data.good_array,
                    'bad_array': data.bad_array
                });
                jQuery("#csv-container > #email_validation_response").eq(0).height();
            }
        });


    });

    jQuery("#email_submit").live('click', function() {
        var container_id = jQuery('#container_id').text();
        var addresses = jQuery('[name=good_address]');
        var address_array = jQuery.map(addresses, function(element){
            return (jQuery(element).text());
        });

        jQuery.ajax({
            type: "post",
            dataType: 'json',
            url: '/rotisserie_instances/queue_email',
            data: {
                'good_addresses': address_array,
                'container_id': container_id,
                'container_type': 'RotisserieInstance'
            },
            success: function(data, textStatus, XMLHttpRequest){
                jQuery("#csv-preview").html("<h2>Invitations will be processed shortly.</h2>");
                jQuery("#csv-emails").val('')
            }
        });


    });
    

});


