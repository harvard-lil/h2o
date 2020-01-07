import AxiosConfig from "axios";
import {get_csrf_token} from 'legacy/lib/helpers';

let headers = {"Content-Type": "application/json",
               "Accept": "application/json"};
const csrf_token = get_csrf_token();
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
