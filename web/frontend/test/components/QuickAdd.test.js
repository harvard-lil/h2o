import { mount, createLocalVue } from "@vue/test-utils";

import Vuex from "vuex";
import sinon from "sinon";

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
              { url: "url1", name: "name1", id: "source-id1", order: 1, search_regexes: [{name: "name1", "regex" : new RegExp("https://cite.case.law/.*"), fuzzy: false}] },
            ],
          },
          namespaced: true,
        },
      },
    });

    const resp = {
      json: sinon.fake.resolves({
        results: [{ id: "fake-id1" }, { id: "fake-id2" }],
      }),
      ok: true,
      status: 200
    };
    
    global.fetch = sinon.fake.resolves(resp);

  });

  afterEach(() => {
    global.fetch = undefined;
  });

  it("loads the quick add form with expected defaults", () => {
    const wrapper = mount(QuickAdd, { store, localVue });
    expect(wrapper.find(".resource-type option:checked").element.textContent).toContain("Section")
    expect(wrapper.find("[type='text']").element.placeholder).toContain("Week One")
  });

  it("updates the resource type dropdown if the user inputs an external link", () => {
    const wrapper = mount(QuickAdd, { store, localVue });
    wrapper.find('[type="text"]').setValue("http://example.com")
    expect(wrapper.find(".resource-type option:checked").element.textContent).toContain("Link")
    expect(wrapper.find("[type='text']").element.placeholder).toContain("example.com")
  });

  it("updates the resource type dropdown if the user inputs text that seems case-like", () => {
    const wrapper = mount(QuickAdd, { store, localVue });
    wrapper.find('[type="text"]').setValue("https://cite.case.law/example");
    expect(wrapper.find(".resource-type option:checked").element.textContent).toContain("Legal Document")
    expect(wrapper.find("[type='text']").element.placeholder).toContain(" v. ")
  });

  it("submits a search request if the inputted item is thought to be a legal document", async () => {
    const wrapper = mount(QuickAdd, { store, localVue });
    wrapper.find('[type="text"]').setValue("https://cite.case.law/example");
    await wrapper.find("form").trigger('submit');
    await new Promise((resolve) => setTimeout(resolve));

    expect(wrapper.vm.mode).toBe("search");
    expect(wrapper.vm.results.length).toBe(2);
  });

  it.only("adds an error message if the search fails", async () => {
    const wrapper = mount(QuickAdd, { store, localVue });
    wrapper.find('[type="text"]').setValue("https://cite.case.law/example");
    
    global.fetch = sinon.fake.resolves({
      json: sinon.fake.resolves({
    
      }),
      ok: false,
      status: 500
    });

    await wrapper.find("form").trigger('submit');
    await new Promise((resolve) => setTimeout(resolve));

    expect(wrapper.vm.mode).toBe("search");
    expect(wrapper.vm.results[0].error).toBeTruthy();
  })
});  
