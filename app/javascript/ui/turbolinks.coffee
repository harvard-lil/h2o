Turbolinks = require 'turbolinks'
Turbolinks.start()

morphdom = require 'morphdom'
Turbolinks.SnapshotRenderer::assignNewBody = ->
  morphdom(document.body,@newBody,{})

Axios = require 'axios'
serialize = require 'form-serialize'

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
    Axios.post form.action,  serialize(form, hash: true),
      onDownloadProgress: (progress)->
        progressBar.setValue progress.loaded / (progress.total or 10000)
    .catch (e)->e.response or throw e
    .then (response)->
      html = response.data
      location = response.request.responseURL
      Turbolinks.controller.cache.put Turbolinks.Location.wrap(location), Turbolinks.Snapshot.fromHTML(html)
      Turbolinks.visit location, action: 'restore'
    .finally -> progressBar.hide()
    .done()
  else if method is 'get'
    Turbolinks.visit "#{form.action}?#{serialize form}"
