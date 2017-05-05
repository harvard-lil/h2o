ui = require 'ui/turbolinks'
draggingOrdinals = null



assignDragLocation = (el, e)->
  rect = el.getBoundingClientRect()
  if e.clientY >= rect.top + rect.height / 2
    if el.firstElementChild.classList.contains 'section'
      el.classList.add 'droppable', 'append'
      if not el.nextElementSibling?.classList.contains 'section-wrapper'
        el.classList.add 'empty'
    else
      el.classList.add 'droppable', 'below'
  else
    el.classList.add 'droppable', 'above'

resetDragClasses = (el)->
  el.classList.remove 'droppable', 'undroppable', 'below', 'above', 'append', 'append-empty'

parseOrdinals = (ordinalString)->
  return unless typeof ordinalString is 'string'
  ordinalString.split('.').map (i)->parseInt i, 10

listingChildren = (sectionListing)->
  sectionWrapper = sectionListing.nextElementSibling
  return [] unless sectionWrapper?.classList.contains 'section-wrapper'
  Array.prototype.filter.call sectionWrapper.firstElementChild.children, (el)->el.classList.contains 'listing-wrapper'

document.addEventListener 'dragstart', (e)->
  return unless e.target.classList.contains 'listing'
  e.stopPropagation()

  e.target.parentElement.classList.add 'drag-from'
  document.querySelector('.table-of-contents').classList.add 'dragging-active'
  setTimeout (->e.target.classList.add 'dragging'), 0
  if e.target.getAttribute 'data-ordinals'
    e.dataTransfer.setData 'text/uri-list', e.target.href
    e.dataTransfer.setData 'text/plain', e.target.href
    e.dataTransfer.setData 'text/ordinals', draggingOrdinals = e.target.getAttribute 'data-ordinals'
    e.dataTransfer.dropEffect = 'move'

document.addEventListener 'dragend', (e)->
  return unless e.target.parentElement.classList.contains 'drag-from'

  resetDragClasses(el) for el in document.querySelectorAll('.droppable, .undroppable')
  e.preventDefault()
  e.stopPropagation()

  document.querySelector('.table-of-contents').classList.remove 'dragging-active'
  e.target.parentElement.classList.remove 'drag-from'
  setTimeout (->e.target.classList.remove 'dragging'), 100
  draggingOrdinals = null

document.addEventListener 'dragenter', (e)->
  return unless e.target.classList.contains('listing-wrapper')
  e.preventDefault()
  e.stopPropagation()

  return if e.target.classList.contains('drag-from')
  return e.target.classList.add('undroppable') if e.target.getAttribute('data-ordinals').startsWith draggingOrdinals

  assignDragLocation e.target, e

document.addEventListener 'dragover', (e)->
  if e.target.classList.contains('droppable')
    e.preventDefault()
    e.stopPropagation()

    resetDragClasses e.target
    assignDragLocation e.target, e

document.addEventListener 'dragleave', (e)->
  console.log 'drag leave happened', e.target.className
  if e.target.classList.contains 'listing-wrapper'
    e.preventDefault()
    e.stopPropagation()

    resetDragClasses e.target

document.addEventListener 'drop', (e)->
  if e.target.classList.contains('droppable')
    e.preventDefault()
    e.stopPropagation()

    ordinals = {}
    if (ordinals.from = parseOrdinals e.dataTransfer.getData('text/ordinals')) and (ordinals.to = parseOrdinals e.target.getAttribute('data-ordinals'))
      if e.target.classList.contains 'above'
        # dragged listing replaces to ordinals
      else if e.target.classList.contains 'below'
        ordinals.to[ordinals.to.length-1] += 1
      else if e.target.classList.contains 'append'
        return if ordinals.to.join('.') is ordinals.from[0..ordinals.from.length-2].join('.')
        ordinals.to.push listingChildren(e.target).length + 1
      else
        return
      return if ordinals.from.join('.') is ordinals.to.join('.')
      ui.patch RAILS_ROUTES.book_section_path(ordinals.from.join '.'), data: {casebook_section: {ordinals: ordinals.to}, reorder: true}
