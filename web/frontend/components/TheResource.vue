<template>
<section class="resource"
         v-selectionchange="selectionchangeHandler">
  <p v-if="annotationsError" role="alert">
    Annotations could not be loaded. <button type="button" :disabled="annotationsLoading" @click="loadAnnotations">Retry</button>
  </p>
  <TheAnnotator v-if="editable && annotationsLoaded"
                ref="annotator"/>
  <TheGlobalElisionExpansionButton v-if="collapsible.length"/>
  <TheResourceBody :resource="resource"/>
</section>
</template>

<script>
import { isAxiosError } from 'axios';
import { captureException } from '@sentry/vue';
import { VerificationCancelledError, VerificationFailedError } from '../libs/requestErrors';
import { createNamespacedHelpers } from "vuex";
const { mapActions } = createNamespacedHelpers("annotations");
const { mapGetters } = createNamespacedHelpers("annotations_ui");

import TheResourceBody from "./TheResourceBody";
import TheAnnotator from "./TheAnnotator";
import TheGlobalElisionExpansionButton from "./TheGlobalElisionExpansionButton";

export default {
  components: {
    TheResourceBody,
    TheAnnotator,
    TheGlobalElisionExpansionButton
  },
  props: {
    resource: {type: Object},
    // The page header is not attached during Vue's created hook.
    resourceId: {type: Number, default: null},
    editable: {type: Boolean}
  },
  data: () => ({
    ranges: null,
    annotationsLoading: false,
    annotationsLoaded: false,
    annotationsError: false
  }),
  computed: {
    ...mapGetters(["collapsible"])
  },
  methods: {
    ...mapActions(["list"]),

    async loadAnnotations() {
      if (!this.resourceId || this.annotationsLoading) return;
      this.annotationsLoading = true;
      try {
        await this.list({resource_id: this.resourceId});
        this.annotationsLoaded = true;
        this.annotationsError = false;
        this.$store.commit("resources_ui/setEditability", this.editable);
      } catch (error) {
        if (!(error instanceof VerificationCancelledError) &&
            !(error instanceof VerificationFailedError) && !isAxiosError(error)) throw error;
        this.annotationsError = true;
        if (!(error instanceof VerificationCancelledError)) captureException(error);
      } finally {
        this.annotationsLoading = false;
      }
    },

    // The selectionchange directive must be bound to the broader
    // <section.resource> (rather than TheAnnotator) so that it has
    // context about which text with which to be concerned.
    // The TheAnnotator handler is then proxied through rather than
    // set directly on the directive because $refs doesn't exist at
    // the point it's added
    selectionchangeHandler(e, sel) {
      this.$refs.annotator && this.$refs.annotator.selectionchange(e, sel);
    }
  },
  created() {
    // Do not allow editing an apparently empty annotation list after a failed load.
    this.$store.commit("resources_ui/setEditability", false);
    return this.loadAnnotations();
  }
}
</script>

<style lang="scss" scoped>
@import '../styles/vars-and-mixins';

.resource {
  position: relative;
  margin-bottom: 24px;
  padding: 40px;
  background-color: $white;
  h5 {
    font-size: 14px;
    margin: 30px 0px 15px 0px;
  }
  h3 {
    @include serif-text($medium, 24px, 27px);
    margin: 10px 0;
    color: $orange;
  }
  @media (max-width: $screen-xs) {
    h2 {
      @include serif-text($bold, 19px, 34px);
    }
  }
  p {
    @include serif-text($regular, 19px, 34px);
  }
  strong {
    @include sans-serif($bold, 18px, 40px);
  }
  .resource-center {
    text-align: center;
  }
}
</style>
