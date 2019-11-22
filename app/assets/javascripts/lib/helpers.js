
export function getQueryStringDict(){
  let queryString = window.location.search.substring(1);
  if (queryString){
      let queryDict = {};
      let queries = queryString.split("&");
      queries.forEach((query) =>{
        let split = query.split('=');
        queryDict[split[0]] = split[1];
      })
      return queryDict;
  } else {
      return {};
  }
}

// from https://docs.djangoproject.com/en/2.2/ref/csrf/#ajax
function getCookie(name) {
    var cookieValue = null;
    if (document.cookie && document.cookie !== '') {
        var cookies = document.cookie.split(';');
        for (var i = 0; i < cookies.length; i++) {
            var cookie = cookies[i].trim();
            // Does this cookie string begin with the name we want?
            if (cookie.substring(0, name.length + 1) === (name + '=')) {
                cookieValue = decodeURIComponent(cookie.substring(name.length + 1));
                break;
            }
        }
    }
    return cookieValue;
}

export function get_csrf_token(){
  // For now, separate handling of csrf in the Rails and Django apps.
  const rails_csrf_el = document.querySelector('meta[name=csrf-token]');
  const django_csrftoken = getCookie('csrftoken');
  let csrf_token = undefined;
  if (rails_csrf_el){
    csrf_token = rails_csrf_el.getAttribute('content');
  } else if (django_csrftoken){
    csrf_token = django_csrftoken;
  }
  return csrf_token;
}
