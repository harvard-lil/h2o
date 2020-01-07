import {patch} from 'legacy/lib/requests';

let draggingOrdinals = null;


function reorder_path(ordinals) {
  if (document.querySelector('header.casebook').dataset.sectionId == ""){
    // when in a casebook
    return FRONTEND_URLS.reorder_casebook_node.replace('_CASEBOOK_ID', document.querySelector('header.casebook').dataset.casebookId).replace('_CHILD_ORDINALS', ordinals);
  } else {
    // when in a section
    return FRONTEND_URLS.reorder_section_node.replace('_CASEBOOK_ID', document.querySelector('header.casebook').dataset.casebookId).replace('_SECTION_ORDINALS', document.querySelector('header.casebook').dataset.sectionOrdinals).replace('_CHILD_ORDINALS', ordinals);
  }
}

function assignDragLocation (el, e) {
  let rect = el.getBoundingClientRect();
  if (e.clientY >= rect.top + rect.height / 2) {
    if (el.firstElementChild.classList.contains('section')) {
      el.classList.add('droppable', 'append');
      if (!(el.nextElementSibling && el.nextElementSibling.classList.contains('section-wrapper'))) {
        el.classList.add('empty');
      }
    } else {
      el.classList.add('droppable', 'below');
    }
  } else {
    el.classList.add('droppable', 'above');
  }
}

function resetDragClasses (el) {
  el.classList.remove('droppable', 'undroppable', 'below', 'above', 'append', 'append-empty');
}

function parseOrdinals (ordinalString) {
  if (typeof ordinalString !==  'string') { return; }
  return ordinalString.split('.').map( i => parseInt(i, 10));
}

function listingChildren (sectionListing) {
  let sectionWrapper = sectionListing.nextElementSibling;
  if (!(sectionWrapper && sectionWrapper.classList.contains('section-wrapper'))) { return []; }
  return Array.prototype.filter.call(sectionWrapper.firstElementChild.children, el => el.classList.contains('listing-wrapper'))
}

document.addEventListener('dragstart', e => {
  if (!e.target.classList.contains('listing') || e.target.dataset.editable === undefined) { return; }
  e.stopPropagation();

  e.target.parentElement.classList.add('drag-from');
  document.querySelector('.table-of-contents').classList.add('dragging-active');
  setTimeout(() => { e.target.classList.add('dragging'); }, 0);

  if (draggingOrdinals = e.target.getAttribute('data-ordinals')) {
    e.dataTransfer.setData('text/uri-list', e.target.href);
    e.dataTransfer.setData('text/plain', e.target.href);
    e.dataTransfer.setData('text/ordinals', draggingOrdinals);
    e.dataTransfer.dropEffect = 'move';
  }
});

document.addEventListener('dragend', e => {
  if (!e.target.parentElement.classList.contains('drag-from')) { return; }

  e.preventDefault();
  e.stopPropagation();

  for (let el of document.querySelectorAll('.droppable, .undroppable')) { resetDragClasses(el); }
  document.querySelector('.table-of-contents').classList.remove('dragging-active');
  e.target.parentElement.classList.remove('drag-from');
  setTimeout(() => { e.target.classList.remove('dragging'); }, 100);

  draggingOrdinals = null;
});

document.addEventListener('dragenter', e => {
  if (!e.target.classList.contains('listing-wrapper')) { return; }

  e.preventDefault();
  e.stopPropagation();

  if (e.target.classList.contains('drag-from')) { return; }
  if (e.target.getAttribute('data-ordinals').startsWith(draggingOrdinals)) {
    e.target.classList.add('undroppable'); // can't drop onto child of dragged listing
    return;
  }

  assignDragLocation(e.target, e);
});

document.addEventListener('dragover', e => {
  if (!e.target.classList.contains('droppable')) { return; }

  e.preventDefault();
  e.stopPropagation();

  resetDragClasses(e.target);
  assignDragLocation(e.target, e);
});

document.addEventListener('dragleave', e => {
  if (!e.target.classList.contains('listing-wrapper')) { return; }

  e.preventDefault();
  e.stopPropagation();

  resetDragClasses(e.target);
});

document.addEventListener('drop', e => {
  if (!e.target.classList.contains('droppable')) { return; }

  e.preventDefault();
  e.stopPropagation();

  let ordinals = {
    from: parseOrdinals(e.dataTransfer.getData('text/ordinals')),
    to: parseOrdinals(e.target.getAttribute('data-ordinals'))
  };
  if (!ordinals.from || !ordinals.to) { return; } // error state, fail silently

  if (e.target.classList.contains('above')) {
    ordinals.to; // new position is the listing we dropped on
  } else if (e.target.classList.contains('below')) {
    ordinals.to[ordinals.to.length-1] += 1; // new position is after the listing we dropped on
  } else if (e.target.classList.contains('append')) {
    if (ordinals.to.join('.') === ordinals.from.slice(0, -2).join('.')) { return; } // no change
    ordinals.to.push(listingChildren(e.target).length + 1); // new position is last child of the listing we dropped on
  } else {
    return; // error state, fail silently
  }

  if (ordinals.from.join('.') === ordinals.to.join('.')) { return; } // no change

  patch(reorder_path(ordinals.from.join('.')), {
    child: { ordinals: ordinals.to },
    reorder: true
  }, { scroll: false, replaceSelector: '.table-of-contents' });
});
