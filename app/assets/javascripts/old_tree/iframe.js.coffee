# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

show_new_iframe_resource = (anchor, target, callback)->
  window.location.hash = target.prop('hash')
  anchor.load(target.prop('href'), callback)
  anchor.data('name', target.html())
  anchor.data('href', target.prop('href'))
  anchor.data('external', target.data('external'))
  anchor.data('type', target.data('type'))
  for key, value of target.data('collage')
    window[key] = value

update_h2o_external_link = (external)->
  $('#breadcrumb-navigation > span:first-child a').prop('href', external)

prep_collage = ->
  h2o_global.adjustArticleHeaderSizes();
  $('.toolbar, #buttons').css('visibility', 'visible');
  collages.observeToolListeners();
  collages.observeLayerColorMapping();
  collages.observeFootnoteLinks();
  collages.observeStatsHighlights();
  collages.slideToParagraph();

set_anchor_id = (anchor)->
  $('body').attr('id', "#{anchor.data('type')}_show")
  

$(document).on 'click', '#single-resource a.local', (e)->
  e.preventDefault()
  anchor = $('#single-resource')
  target = $(e.target)
  name = target.html()
  href = target.prop('href')
  show_new_iframe_resource anchor, target, (response, status, j)=>
    if status != 'error'
      set_anchor_id(anchor)
      external = $('#single-resource').data('external')
      node = $("<span><a href=\"#{href}\" class=\"btn Button Button--small\">#{name}</a></span>")
      link = node.find('a')
      link.data(target.data())
      link.data('external', external)
      $('#breadcrumb-navigation').append(node)
      update_h2o_external_link(external)
      h2o_global.loadEditability()
      prep_collage()
      window.scrollTo(0, 0) unless window.location.hash
    else
      alert("We're sorry. Something went wrong.")

$(document).on 'click', '#breadcrumb-navigation a:not(.external)', (e)->
  e.preventDefault()
  target = $(e.target)
  anchor = $('#single-resource')
  show_new_iframe_resource anchor, target, (response, status, j)=>
    if status != 'error'
      set_anchor_id(anchor)
      target.parent('span').nextAll().remove()
      external = target.data('external')
      update_h2o_external_link(external)
      h2o_global.loadEditability()
      prep_collage()
    else
      alert("We're sorry. Something went wrong.")

$(document).on 'click', '#single-resource #main-wedge', ->
  $('#main_details').toggleClass('ui-accordion-header-active')
  is_on = $('#main_details').hasClass('ui-accordion-header-active')
  $('.main_playlist .listitem > .wrapper').toggleClass('ui-accordion-header-active', is_on)

$(document).on 'click', '#single-resource .wrapper table .rr', ->
  $(this).closest('.wrapper').toggleClass('ui-accordion-header-active')
