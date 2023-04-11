<template>
  <fieldset class="advanced-search">
    <label>
      Source:
      <select class="form-control" v-model="formData.source">
        <option :value="undefined">All sources</option>
        <option v-for="source in sources" :value="source.id" :key="source.id">
          {{ source.name }}
        </option>
      </select>
    </label>
    <label>
      Jurisdiction:
      <select
        class="form-control"
        v-model="formData.jurisdiction"
        name="jurisdiction"
      >
        <option :value="undefined">All jurisdictions</option>
        <option v-for="j in jurisdictions" :value="j.val" :key="j.val">
          {{ j.name }}
        </option>
      </select>
    </label>
    <label>
      Decision Date
      <fieldset>
        <input
          v-model="formData.afterDate"
          name="after_date"
          type="date"
          class="form-control"
          placeholder="YYYY-MM-DD"
        />
        <span> - </span>
        <input
          v-model="formData.beforeDate"
          name="before_date"
          type="date"
          class="form-control"
          placeholder="YYYY-MM-DD"
        />
      </fieldset>
    </label>
    <p
      v-for="s in sources"
      :key="s.id"
      :data-source-selected="formData.source === s.id"
      class="source-description"
    >
      {{ s.long_description }}
    </p>
  </fieldset>
</template>

<script>
import { jurisdictions } from "../../libs/legal_document_search";

export default {
  props: {
    sources: {
      type: Array,
    },
    formData: {
      type: Object,
      required: true,
    },
  },
  data: () => ({
    jurisdictions,
  }),
  watch: {
    formData() {
      this.$emit("update", this.formData);
    },
  },
};
</script>

<style lang="scss" scope>
.advanced-search {
  display: flex;
  gap: 1em;
  flex-wrap: wrap;
  margin: 1em 0;
  flex-basis: 100%;

  label {
    width: 100%;
    line-height: 2em;

    & * {
      font-weight: normal;
    }
    select {
      padding-left: 0.5em;
    }
  }
  & > label {
    flex-basis: 24%;
  }
  & > label:last-of-type {
    flex-basis: 48%;
    fieldset {
      display: flex;
      gap: 1em;
      align-items: center;
      justify-content: center;
      input {
        padding: 3px;
        text-indent: 10px;
      }
    }
  }
  .form-control {
    font-size: 16px;
  }
  p.source-description {
    flex-basis: 100%;
    display: none;
  }
  p.source-description[data-source-selected] {
    display: block;
  }
}
</style>