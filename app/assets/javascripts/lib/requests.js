import Axios from 'axios';

export function request (url, method, data = {}, options = {scroll: true}) {
    let promise = Axios.post(url, data, {
      headers: {
        'X-HTTP-Method-Override': method,
        'X-CSRF-Token': document.querySelector('meta[name=csrf-token]').getAttribute('content')
      }, 
      timeout: 5000,
    });

    promise.catch(e => {
      if (e.response) return e.response;
      throw e;
    })
    .then(response => {
      let html = response.data;
      let location = response.request.responseURL;

      if ((window.location.href == location) || (method == 'delete')){
        window.location.reload(true); // save scroll position for annotations
      } else {
        window.location.replace(location);
      }

      if (options["modal"]){
        options["modal"].destroy();
      }

    })
    .done(); 

    console.log("about to return promise")

    return promise;
}

export var get = (url, data = {}, options = {}) => request(url, 'get', data, options)
export var post = (url, data = {}, options = {}) => request(url, 'post', data, options)
export var rest_delete = (url, data = {}, options = {}) => request(url, 'delete', data, options)
export var patch = (url, data = {}, options = {}) => request(url, 'patch', data, options)
