import Vue from "vue";
import AxiosConfig from "axios";

let headers = {"Content-Type": "application/json",
               "Accept": "application/json"};
// For now, separate handling of csrf in the Rails and Django apps.
const rails_csrf_el = document.querySelector('meta[name=csrf-token]');
const django_csrf_el = document.querySelector('[name=csrfmiddlewaretoken]');
let csrf_token = undefined;
if (rails_csrf_el){
  csrf_token = rails_csrf_el.getAttribute('content');
} else if (django_csrf_el){
  csrf_token = django_csrf_el.value;
}
if(csrf_token) headers["X-CSRF-Token"] = csrf_token;

const Axios = AxiosConfig.create({headers: headers});

// Add method override to request
Axios.interceptors.request.use(config => {
  const method = config.method.toUpperCase();
  if (["PUT", "DELETE", "PATCH"].includes(method)) {
    config.headers = {
      ...config.headers,
      ["X-HTTP-Method-Override"]: method,
    };
    config.method = "post";
  }
  return config;
});

export default Axios;
