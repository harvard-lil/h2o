import { mount } from "@vue/test-utils";
import AdvancedSearch from "@/components/LegalDocumentSearch/AdvancedSearch";

it("only marks the selected source description for display", async () => {
  const wrapper = mount(AdvancedSearch, {
    props: {
      sources: [
        { id: 1, name: "First", long_description: "First source" },
        { id: 2, name: "Second", long_description: "Second source" },
      ],
      formData: {},
    },
  });
  expect(wrapper.find("[data-source-selected]").exists()).toBe(false);
  await wrapper.setProps({ formData: { source: 2 } });
  expect(wrapper.findAll("[data-source-selected]")).toHaveLength(1);
  expect(wrapper.find("[data-source-selected]").text()).toBe("Second source");
  await wrapper.setProps({ formData: {} });
  expect(wrapper.find("[data-source-selected]").exists()).toBe(false);
});
