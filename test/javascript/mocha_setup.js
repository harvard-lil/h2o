require('jsdom-global')();

global.expect = require('expect');
global.DOMParser = window.DOMParser;

// https://github.com/vuejs/vue-test-utils/issues/936#issuecomment-415386167
window.Date = Date;
