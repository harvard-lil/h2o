### eslint no-console:0 ###

axios = require 'axios'
serialize = require 'form-serialize'
Turbolinks = require 'turbolinks'

Turbolinks.start()

document.addEventListener 'submit', (e)->
  console.log 'submit', arguments
  form = e.target
  if !form.getAttribute('data-remote')
    return

  e.preventDefault()
  method = form.method or 'get'
  if method is 'post'
    console.log  serialize(form, hash: true)
    progressBar = new Turbolinks.ProgressBar
    progressBar.show()
    axios.post form.action,  serialize(form, hash: true),
      onDownloadProgress: (progress)->
        progressBar.setValue progress.loaded / (progress.total or 10000)
    .then (html)->
      Turbolinks.controller.cache.put Turbolinks.Location.wrap(form.action), Turbolinks.Snapshot.fromHTML(html.data)
      Turbolinks.visit form.action, action: 'restore'
      progressBar.hide()
