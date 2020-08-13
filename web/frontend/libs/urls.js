import _ from 'lodash';

function url(urlName) {
    const arr = FRONTEND_URLS[urlName];
    if (!arr) {
        console.error(`${urlName} not present in FRONTEND_URLS`);
        return false;
    }
    const urlParts = arr;
    return (params) => {
        return '/' + urlParts.map(part => _.get(params, part.substr(1), part)).join("/");
    };
}

function matcher(urlName) {
    const arr = FRONTEND_URLS[urlName];
    if (!arr) {
        console.error(`${urlName} not present in FRONTEND_URLS`);
        return false;
    }
    return new RegExp('^'+ location.origin + '/' + _.map(arr, x => x.length > 0 && x[0] === '_' ? '[^/]*' : x).join("/") + '$');
}

function reverser(urlName) {
    const arr = FRONTEND_URLS[urlName];
    if (!arr) {
        console.error(`${urlName} not present in FRONTEND_URLS`);
        return false;
    }
    return (url) => {
        let path = url.split('/').splice(3);
        let ret = {};
        _.zip(arr,path).forEach(([template, actual]) => {
            if (template.length > 0 && template[0] === "_") {
                let key = template.substr(1);
                ret[key] = actual;
            }
        });
        return ret;
    };
}

export default { url, matcher, reverser };
