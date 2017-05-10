import Turbolinks from 'turbolinks';
import Axios from 'axios';

export function request (url, method, {data = {}}) {
    let progressBar = new Turbolinks.ProgressBar;
    progressBar.show();

    Axios.post(url, data, {
      headers: {
        'X-HTTP-Method-Override': method,
        'X-CSRF-Token': document.querySelector('meta[name=csrf-token]').getAttribute('content')
      },
      onDownloadProgress: progress => {
        progressBar.setValue(progress.loaded / (progress.total || 10000))
      }
    })
    .catch(e => {
      if (e.response) return e.response;
      throw e;
    })
    .then(response => {
      let html = response.data;
      let location = response.request.responseURL;
      Turbolinks.controller.cache.put(Turbolinks.Location.wrap(location), Turbolinks.Snapshot.fromHTML(html));
      Turbolinks.visit(location, {action: 'restore', scroll: false});
    })
    .finally(_ => progressBar.hide())
    .done()
}
export var get = (url, options = {}) => request(url, 'get', options)
export var post = (url, options = {}) => request(url, 'post', options)
export var patch = (url, options = {}) => request(url, 'patch', options)
