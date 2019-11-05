import Axios from 'axios';

function destroy_modal(modal) {
  if(modal){
    modal.el.dataset.processing = "false";
    modal.destroy();
  }
}

export function request (url, method, data = {}, options = {scroll: true}) {

  // For now, separate handling of csrf in the Rails and Django apps.
  // Remark: in Django land, this probably wants to get the token from
  // the user's cookie, rather than from the DOM; punting for now.
  const rails_csrf_el = document.querySelector('meta[name=csrf-token]');
  const django_csrf_el = document.querySelector('[name=csrfmiddlewaretoken]');
  let csrf_token = undefined;
  if (rails_csrf_el){
    csrf_token = rails_csrf_el.getAttribute('content');
  } else if (django_csrf_el){
    csrf_token = django_csrf_el.value;
  }
  let headers = csrf_token ? {'X-CSRF-Token': csrf_token} : {};
  headers['X-HTTP-Method-Override'] = method;

  let promise = Axios.post(url, data, {headers: headers});

    promise.catch(e => {
      if (e.response) return e.response;
      throw e;
    })
    .then(response => {

      // Throw in some quick error handling.
      if (response.status != 200) {
        // The user should be notified here; we don't have a mechanism
        // for doing that yet, and I don't want to use alert();
        console.error(`AJAX request failed with ${response.status}.`)

        destroy_modal(options["modal"])
        return
      }

      // This code actually expects successful AJAX requests to receive
      // a redirect as a response. Axios follows the redirect, performing
      // a GET of the page we want the browser to display next. Here, we
      // examine the URL of we just retrieved, and compare it to the URL
      // of the page we are presently on. If we are already on that page,
      // we perform a refresh. Otherwise, we direct the browser there.
      // In all cases, this performs a duplicate GET.
      //
      // Let's have a think on how we might redesign this in the future.
      // Probably a mix of more Vue, and switching from AJAX to standard
      // form submissions.
      let html = response.data;
      let location = response.request.responseURL;

      if ((window.location.href == location) || (method == 'delete')){
        // saving scroll position
        if (navigator.userAgent.match('Firefox') != null){
          window.location.reload(false);
        }
        else {
          window.location.reload(true);
        }
      } else {
        window.location.replace(location);
      }

      // Is this code reachable? I don't see how; keeping it for now.
      destroy_modal(options["modal"])

    })
    .done();

    return promise;
}

export var get = (url, data = {}, options = {}) => request(url, 'get', data, options)
export var post = (url, data = {}, options = {}) => request(url, 'post', data, options)
export var rest_delete = (url, data = {}, options = {}) => request(url, 'delete', data, options)
export var patch = (url, data = {}, options = {}) => request(url, 'patch', data, options)
