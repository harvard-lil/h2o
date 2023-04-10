import { mount, createLocalVue } from "@vue/test-utils";

import Vuex from "vuex";

import QuickAdd from "@/components/QuickAdd";

const localVue = createLocalVue();
localVue.use(Vuex);

describe("QuickAdd", () => {
 let store;

  beforeEach(() => {
    store = new Vuex.Store({
      modules: {
        case_search: {
          getters: {
            getSources: () => [
              { url: "url1", name: "name1", id: "source-id1", order: 1, search_regexes: [] },
              { url: "url2", name: "name2", id: "source-id2", order: 2, search_regexes: [] },
            ],
          },
          namespaced: true,
        },
      },
    });
  });
  it("loads the quick add form with expected defaults", () => {
    const wrapper = mount(QuickAdd, { store, localVue });
    expect(wrapper.find(".resource-type option:checked").element.textContent).toContain("Section")
  })
});  
