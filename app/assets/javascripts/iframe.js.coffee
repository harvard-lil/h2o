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
  $('body').attr('id', "#{anchor.data('type')}_show")
  for key, value of target.data('collage')
    window[key] = value

update_h2o_external_link = (external)->
  $('#breadcrumb-navigation > span:first-child a').prop('href', external)

prep_collage = ->
  $('.toolbar, #buttons').css('visibility', 'visible');
  collages.observeToolListeners();
  collages.observeLayerColorMapping();
  collages.observeFootnoteLinks();
  collages.observeStatsHighlights();
  collages.slideToParagraph();

$(document).on 'click', '#single-resource a.local', (e)->
  e.preventDefault()
  anchor = $('#single-resource')
  target = $(e.target)
  name = target.html()
  href = target.prop('href')
  show_new_iframe_resource anchor, target, (response, status, j)=>
    if status != 'error'
      external = $('#single-resource').data('external')
      node = $("<span><a href=\"#{href}\" class=\"btn Button--secondary\">#{name}</a></span>")
      link = node.find('a')
      link.data(target.data())
      link.data('external', external)
      $('#breadcrumb-navigation').append(node)
      update_h2o_external_link(external)
      h2o_global.loadEditability()
      prep_collage()
    else
      alert("We're sorry. Something went wrong.")

$(document).on 'click', '#breadcrumb-navigation a:not(.external)', (e)->
  e.preventDefault()
  target = $(e.target)
  show_new_iframe_resource $('#single-resource'), target, (response, status, j)=>
    if status != 'error'
      target.parent('span').nextAll().remove()
      external = target.data('external')
      update_h2o_external_link(external)
      h2o_global.loadEditability()
      prep_collage()
    else
      alert("We're sorry. Something went wrong.")

$(document).on 'click', '#single-resource #main-wedge', ->
  $('#main_details').toggleClass('ui-accordion-header-active')
  $('#main_details').toggleClass('ui-state-active')
  is_on = $('#main_details').hasClass('ui-accordion-header-active')
  $('.main_playlist .listitem > .wrapper').toggleClass('ui-accordion-header-active', is_on)
  $('.main_playlist .listitem > .wrapper').toggleClass('ui-state-active', is_on)

$(document).on 'click', '#single-resource .wrapper table .rr', ->
  $(this).closest('.wrapper').toggleClass('ui-accordion-header-active')
  $(this).closest('.wrapper').toggleClass('ui-state-active')
