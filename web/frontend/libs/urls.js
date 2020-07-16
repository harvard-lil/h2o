import _ from 'lodash';
const varMatcher = /_[A-Z_]*/g;

function url(urlName) {
    const str = FRONTEND_URLS[urlName];
    if (!str) {
        console.error(`${urlName} not present in FRONTEND_URLS`);
        return;
    }
    let parts = str.split(varMatcher);
    let vars = _.map(str.match(varMatcher), (x) => _.camelCase(x));
    return (params) => {
        let values = vars.map(k => params[k]);
        return _.flatten(_.zip(parts, values)).join('');
    };
}

export default { url };
