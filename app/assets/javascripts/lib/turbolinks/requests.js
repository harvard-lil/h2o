import Turbolinks from 'turbolinks';
import Axios from 'axios';

export function request (url, method, data = {}, options = {scroll: true}) {
    let progressBar = new Turbolinks.ProgressBar;
    progressBar.show();

    let promise = Axios.post(url, data, {
      headers: {
        'X-HTTP-Method-Override': method,
        'X-CSRF-Token': document.querySelector('meta[name=csrf-token]').getAttribute('content')
      },
      onDownloadProgress: progress => {
        progressBar.setValue(progress.loaded / (progress.total || 10000))
      }
    });

    promise.catch(e => {
      if (e.response) return e.response;
      throw e;
    })
    .then(response => {
      let html = response.data;
      let location = response.request.responseURL;
      Turbolinks.controller.cache.put(Turbolinks.Location.wrap(location), Turbolinks.Snapshot.fromHTML(html));
      if (!options.scroll) {
        Turbolinks.keepScrollPosition();
      }
      Turbolinks.visit(location, {action: 'restore'});
    })
    .finally(_ => progressBar.hide())
    .done();

    return promise;
}
export var get = (url, data = {}, options = {}) => request(url, 'get', data, options)
export var post = (url, data = {}, options = {}) => request(url, 'post', data, options)
export var patch = (url, data = {}, options = {}) => request(url, 'patch', data, options)
