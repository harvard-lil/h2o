jQuery(document).ready(function(){
  var height = jQuery('.description').height();
  if(height != 30) {
    jQuery('.toolbar,.buttons').css({ position: 'relative', top: height - 30 });
  }
  jQuery('.toolbar, .buttons').css('visibility', 'visible');
});
