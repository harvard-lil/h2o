import Promise from 'bluebird';
window.Promise = Promise;
Promise.config({
  longStackTraces: true,
  warnings: true
});
