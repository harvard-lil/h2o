<template>
  <section>
  <ol :class="selectedResult ? 'adding' : ''">
    <li v-if="sorted.length > 0" class="labels">
      <span class="name">Case</span>
      <span class="cite">Citation</span>
      <span class="date">Effective date</span>
      <span class="source">Source</span>
    </li>
    <li
      v-for="r in sorted"
      @click="(e) => add(e.target.closest('li'), r.id, r.sourceId)"
      @keyup.enter="(e) => add(e.target.closest('li'), r.id, r.sourceId)"
      :data-result-selected="r.id === selectedResult"
      :data-result-added="added && r.id === added.sourceRef"
      :key="r.id"
      class="results-entry"
      role="button"
      tabindex="0"
    >
      <span class="name" :title="r.fullName">{{ r.shortName }}</span>
      <span class="cite" :title="r.fullCitations">{{ r.shortCitations }}</span>
      <span class="date">{{ r.effectiveDate }}</span>
      <span class="source">
        <a v-if="r.url" target="_blank" title="Open on external site" :href="r.url"
          >{{ r.name }}</a
        >
        <span v-else>{{ r.name }}</span>
      </span>
      <span class="added-message" v-if="added && r.id === added.sourceRef">
        <span class="success-message"
          >This document has been added to your casebook.</span
        >
        <button class="btn btn-primary" @click="edit">Edit document</button>
        <button class="btn btn-default" @click="$emit('reset-search')">New search</button>
        <button class="btn btn-default btn-close" @click="$emit('close')">Close</button>
      </span>
    </li>
  </ol>
  <p v-if="Array.isArray(searchResults) && searchResults.length === 0">
    No legal documents were found matching your search.
  </p>
  </section>
</template>

<script>
export default {
  props: {
    searchResults: Array,
    selectedResult: String,
    added: Object,
  },
  data: () => ({
    adding: false,
  }),
  computed: {
     sorted() {     
      return [...this.searchResults || []].sort((a, b) => a.sourceOrder - b.sourceOrder)
     }
  },
  methods: {
    edit: function () {
      location.href = this.added.redirectUrl;
    },
    add: function (row, id, sourceId) {
      if (this.selectedResult) {
        return;
      }
      row.classList.toggle("adding");
      this.$emit("add-doc", id, sourceId);
    },
  },
};
</script>

<style lang="scss" scoped>
ol {
  padding: 0;
  list-style-type: none;
  font-size: 16px;

  li:first-of-type {
    font-weight: bold;

    &:hover,
    &:focus-within {
      background: none;
    }
  }

  li + li {
    border-top: 0.5px solid rgb(149, 149, 149);
  }
  &.adding {
    li:not([data-result-selected]):not(.labels) {
      display: none;
    }

    li:hover,
    li:focus-within {
      background: inherit;
    }
    li[data-result-selected] {
      background: hsl(43, 94%, 80%);
      cursor: wait;
    }
    li[data-result-added] {
      background: initial;
      cursor: auto;
    }
  }

  li {
    display: flex;
    flex-wrap: wrap;
    justify-content: space-between;
    align-items: flex-start;
    padding: 0.5em;
    gap: 0.5em;

    &:hover,
    &:focus-within {
      background: hsl(43, 94%, 80%);
    }
    .name {
      flex-basis: 40%;
    }

    .cite {
      flex-basis: 30%;
    }

    .date {
      flex-basis: 10ch;
      flex-grow: 1;
    }
    .source {
      flex-grow: 1;
    }
    .added-message {
      margin-top: 2em;
      flex-basis: 100%;
      display: flex;
      flex-wrap: wrap;
      gap: 1em;
      justify-content: space-between;
      .success-message {
        flex-basis: 100%;
      }
      button {
        width: 30%;

        &.btn-close {
          background: gray;
        }
      }
    }
    a {
      text-decoration: underline !important;
      text-underline-offset: 4px;
    }
    a[href^="http"]:after {
      content: url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAQElEQVR42qXKwQkAIAxDUUdxtO6/RBQkQZvSi8I/pL4BoGw/XPkh4XigPmsUgh0626AjRsgxHTkUThsG2T/sIlzdTsp52kSS1wAAAABJRU5ErkJggg==);
      margin: 0 0 0 0.5em;
    }
  }
}
</style>
