Turbolinks = require 'turbolinks'
Turbolinks.start()

morphdom = require 'morphdom'
Turbolinks.SnapshotRenderer::assignNewBody = ->
  morphdom(document.body,@newBody,{})

Axios = require 'axios'
serialize = require 'form-serialize'
querystring = require 'query-string'

module.exports = ui =
  request: (url, method, {data})->
    data ?= {}

    progressBar = new Turbolinks.ProgressBar
    progressBar.show()

    Axios[method] url, data,
      headers:
        'X-CSRF-Token': document.querySelector('meta[name=csrf-token]').getAttribute('content')
      onDownloadProgress: (progress)->
        progressBar.setValue progress.loaded / (progress.total or 10000)
    .catch (e)->e.response or throw e
    .then (response)->
      html = response.data
      location = response.request.responseURL
      Turbolinks.controller.cache.put Turbolinks.Location.wrap(location), Turbolinks.Snapshot.fromHTML(html)
      Turbolinks.visit location, action: 'restore', scroll: false
    .finally -> progressBar.hide()
    .done()
  post: (url, options = {})->ui.request url, 'post', options
  patch: (url, options = {})->ui.request url, 'patch', options

document.addEventListener 'submit', (e)->
  console.log 'submit', arguments
  form = e.target
  return if form.getAttribute('data-turbolinks-disable')
  e.preventDefault()
  if form.method is 'post'
    ui.post form.action, data: serialize(form)
  else if form.method is 'get'
    Turbolinks.visit "#{form.action}?#{serialize form}"
