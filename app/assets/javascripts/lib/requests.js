import Axios from 'axios';

export function request (url, method, data = {}, options = {scroll: true}) {
  const csrf_el = document.querySelector('meta[name=csrf-token]');
  let headers = csrf_el ? {'X-CSRF-Token': csrf_el.getAttribute('content')} : {};
  headers['X-HTTP-Method-Override'] = method;

  let promise = Axios.post(url, data, {headers: headers});

    promise.catch(e => {
      if (e.response) return e.response;
      throw e;
    })
    .then(response => {
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

      if (options["modal"]){
        options["modal"].destroy();
      }

    })
    .done(); 

    return promise;
}

export var get = (url, data = {}, options = {}) => request(url, 'get', data, options)
export var post = (url, data = {}, options = {}) => request(url, 'post', data, options)
export var rest_delete = (url, data = {}, options = {}) => request(url, 'delete', data, options)
export var patch = (url, data = {}, options = {}) => request(url, 'patch', data, options)
