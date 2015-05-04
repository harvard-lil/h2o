# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

show_new_iframe_resource = (anchor, target, callback)->
  anchor.load(target.prop('href'), callback)
  anchor.data('name', target.html())
  anchor.data('href', target.prop('href'))

$(document).on 'click', '#single-resource a.local', (e)->
  e.preventDefault();
  anchor = $('#single-resource')
  target = $(e.target)
  name = target.html()
  href = target.prop('href')
  show_new_iframe_resource anchor, target, (response, status, j)=>
    if status != 'error'
      $('#breadcrumb-navigation').append(
        $("<span> &gt; <a href=\"#{href}\">#{name}</a></span>")
      )
    else
      alert("We're sorry. Something went wrong.")

$(document).on 'click', '#breadcrumb-navigation a', (e)->
  e.preventDefault();
  target = $(e.target)
  show_new_iframe_resource $('#single-resource'), target, (response, status, j)=>
    if status != 'error'
      target.parent('span').nextAll().remove()
    else
      alert("We're sorry. Something went wrong.")
