import {
  mount
} from "@vue/test-utils";

import ResultsForm from "@/components/LegalDocumentSearch/ResultsForm";

describe("ResultsForm", () => {
  const id = "99";
  const sourceId = "2";
  const sourceOrder = 1;
  const searchResults = [{
    id,
    sourceId,
    sourceOrder,
  }, ];
  const selectedResult = id;
  const added = {
    sourceRef: id
  };

  it("triggers the add-doc event when clicked", async () => {
      const wrapper = mount(ResultsForm, {
        props: {
          searchResults,
        },
      });
      expect(wrapper.find("No legal documents were found").exists()).toBe(false);
      await wrapper.find("li:nth-of-type(2)").trigger("click");
      expect(wrapper.emitted("add-doc")).toBeTruthy();
      expect(wrapper.emitted("add-doc")[0]).toEqual([id, sourceId]);
  });

  it("only marks the selected result for selection styling", async () => {
    const wrapper = mount(ResultsForm, { props: { searchResults } });
    expect(wrapper.find("[data-result-selected]").exists()).toBe(false);
    await wrapper.setProps({ selectedResult: id });
    expect(wrapper.find("[data-result-selected]").attributes("data-result-id")).toBe(id);
    await wrapper.setProps({ selectedResult: null });
    expect(wrapper.find("[data-result-selected]").exists()).toBe(false);
  });

  it("does not allow submitting more than once", async () => {
    const wrapper = mount(ResultsForm, {
      props: {
        searchResults,
        selectedResult,
      },
    });
    await wrapper.find("li:nth-of-type(2)").trigger("click");
    expect(wrapper.emitted("add-doc")).not.toBeTruthy();
  });
  
  it("sorts results by the order of source information", async () => {
    const searchResults = [{
        id: 3,
        sourceId: 1,
        sourceOrder: 3
      },
      {
        id: 1,
        sourceId: 1,
        sourceOrder: 1
      },
      {
        id: 2,
        sourceId: 1,
        sourceOrder: 2
      },
    ];
    const wrapper = mount(ResultsForm, {
      props: {
        searchResults,
      },
    });
    expect(
      wrapper.find("li:nth-of-type(2)").attributes("data-result-id")
    ).toEqual("1");
    expect(
      wrapper.find("li:nth-of-type(3)").attributes("data-result-id")
    ).toEqual("2");
    expect(
      wrapper.find("li:nth-of-type(4)").attributes("data-result-id")
    ).toEqual("3");
  });

  it("displays only the added result if added", async () => {
    const wrapper = mount(ResultsForm, {
      props: {
        searchResults,
        selectedResult,
        added,
      },
    });

    expect(wrapper.text()).toContain("This document has been added");
  });

  it("display a no-results message if the result list was empty", async () => {
    const emptyResults = [];
    const wrapper = mount(ResultsForm, {
      props: {
        searchResults: emptyResults,
      },
    });

    expect(wrapper.text()).toContain("No legal documents were found");

    expect(
      mount(ResultsForm, {
        props: {
          searchResults,
        },
      }).text()
    ).not.toContain("No legal documents were found");
  });

});