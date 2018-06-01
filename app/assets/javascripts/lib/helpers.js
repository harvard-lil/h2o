
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
