$(document).ready(function(){

	$("#results .sort select").selectbox({
		className: "jsb"
	});
	
	$('#results .song details .influence input').rating();
	$('#playlist details .influence input').rating();
	
	$("#results .song .controls ul li.link-add").click(function() {
		$(this).parents(".song").toggleClass("song-active").find(".add-popup").toggle();
		
		return false;
	});
	
	$("#search .btn-tags").click(function() {
		var $p = $(".browse-tags-popup");
		
		$p.toggle();
		$(this).toggleClass("active");
		
		return false;
	});
	
	$("#playlist .playlist .data .dd-open").click(function() {
		$(this).parents(".playlist:eq(0)").find(".playlists:eq(0)").slideToggle();
		
		return false;
	});
	
	$("#collage .description .buttons ul .btn-a span").parent().click(function() {
		$(this).parents(".btn-li").find(".popup").toggle();
		$(this).toggleClass("btn-a-active");
		
		return false;
	});

});