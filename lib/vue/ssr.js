import { createRenderer } from "vue-server-renderer";
import Vue from "vue";
import store from "store/index";
import TheResourceBody from "components/TheResourceBody";

process.stdin.setEncoding('utf8');

let data = '';
process.stdin.on('readable', () => {
  let chunk;
  while ((chunk = process.stdin.read()) !== null) {
    data += chunk;
  }
});

process.stdin.on('end', () => {
  const json = JSON.parse(data);
  store.commit('annotations/append', json.annotations);

  const app = new Vue({
    store,
    render: h => h(TheResourceBody, {props: {resource: {content: json.content}}})
  });

  const renderer = createRenderer();
  renderer.renderToString(app, (err, html) => {
    if (err) throw err;
    process.stdout.write(html);
  });
});
