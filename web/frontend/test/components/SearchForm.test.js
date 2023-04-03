import { mount, createLocalVue } from "@vue/test-utils";
import SearchForm from "@/components/LegalDocumentSearch/SearchForm";
import Vuex from "vuex";
import sinon from "sinon";

const localVue = createLocalVue();
localVue.use(Vuex);

describe("SearchForm", () => {
  let store;

  beforeEach(() => {
    const resp = {
      json: sinon.fake.resolves({
        results: [{ id: "fake-id1" }, { id: "fake-id2" }],
      }),
    };
    global.fetch = sinon.fake.resolves(resp);

    store = new Vuex.Store({
      modules: {
        case_search: {
          getters: {
            getSources: () => [
              { url: "url1", name: "name1", id: "source-id1", order: 1 },
              { url: "url2", name: "name2", id: "source-id2", order: 2 },
            ],
          },
          namespaced: true,
        },
      },
    });
  });
  afterEach(() => {
    global.fetch = undefined;
  });

  it("allows toggling the advanced search fields", async () => {
    const wrapper = mount(SearchForm, { store, localVue });

    const button = wrapper.find("button.advanced-search-toggle");
    expect(button.text()).toContain("Advanced search");
    expect(wrapper.find('input[type="date"]').exists()).toBe(false);
    await button.trigger("click");
    expect(button.text()).toContain("Basic search");
    expect(wrapper.find('input[type="date"]').exists()).toBe(true);
  });

  it("triggers the results event when submitted", async () => {
    const wrapper = mount(SearchForm, { store, localVue });
    wrapper.find('input[type="text"]').setValue("test");
    wrapper.find("form").trigger("submit");
    await new Promise((resolve) => setTimeout(resolve));
    expect(wrapper.emitted()["search-results"].length).toBe(1); // Called once
    // Expect 4 search results, 2 for each source
    expect(wrapper.emitted()["search-results"][0][0].length).toBe(4); 
  });
});
