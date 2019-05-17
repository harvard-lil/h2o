// This file is used by the rails annotations:compare_ruby_to_js task

import { mount,
         createLocalVue } from "@vue/test-utils";

import Vuex from "vuex";
import annotations from "store/modules/annotations";
import annotations_ui from "store/modules/annotations_ui";
import footnotes_ui from "store/modules/footnotes_ui";
import resources_ui from "store/modules/resources_ui";

import TheResourceBody from "components/TheResourceBody";

const localVue = createLocalVue();
localVue.use(Vuex);

const store = new Vuex.Store({
  modules: {annotations,
            annotations_ui,
            footnotes_ui,
            resources_ui}
});

let data = '';

process.stdin.setEncoding('utf8');

process.stdin.on('readable', () => {
  let chunk;
  while ((chunk = process.stdin.read()) !== null) {
    data += chunk;
  }
});

process.stdin.on('end', () => {
  const json = JSON.parse(data);
  const wrapper = mount(TheResourceBody, {store, localVue, propsData: {
    resource: {content: json.content}
  }});

  const offsets = Array.from(wrapper.element.querySelectorAll(".case-text > *")).reduce(((a, n) => a.concat([a[a.length -1 ] + n.textContent.length])), [0]);

  process.stdout.write(JSON.stringify(offsets));
});
