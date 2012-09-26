function fieldTable(title){
  var res = title
  
  res += '<table>';
  res += '<tr><td width="150">Full Name:</td><td>' + jQuery('#case_request_full_name').val() + '</td></tr>';
  res += '<tr><td>Decision Date:</td><td>' + jQuery('#case_request_decision_date').val() + '</td></tr>';
  res += '<tr><td>Author:</td><td>' + jQuery('#case_request_author').val() + '</td></tr>';
  res += '<tr><td>Docket Number:</td><td>' + jQuery('#case_request_docket_number').val() + '</td></tr>';
  res += '<tr><td>Volume:</td><td>' + jQuery('#case_request_volume').val() + '</td></tr>';
  res += '<tr><td>Reporter:</td><td>' + jQuery('#case_request_reporter').val() + '</td></tr>';
  res += '<tr><td>Page:</td><td> ' + jQuery('#case_request_page').val() + '</td></tr>';
  res += '<tr><td>Bluebook Citation:</td><td>' + jQuery('#case_request_bluebook_citation').val() + '</td></tr>';
  res += '</table>';
  res += '</div>';
  return res;
}

function initConfirmDialog(node_data){

  jQuery(node_data).dialog({
    resizable: false,
    height: 280,
    width: 400,
    modal: true,
    buttons: {
             "Finalize Submission": function(){
                  jQuery(this).dialog('close');
                  jQuery('form#case_request-form').submit();

             },
             Cancel: function(){
                  jQuery(this).dialog('close');
             }
    }
  });
}

jQuery(document).ready(function() {
  jQuery.observeMetadataForm();

  jQuery('.create').click(function(){
  var confirmNode = fieldTable('<div title="New Case Request">');

  var confirmNode = jQuery(confirmNode);
  initConfirmDialog(confirmNode);  
    return false;
  });

  jQuery('.update').click(function(){
  var confirmNode = fieldTable('<div title="Edit Case Request">');

  var confirmNode = jQuery(confirmNode);
  initConfirmDialog(confirmNode);  
    return false;
  });

});
