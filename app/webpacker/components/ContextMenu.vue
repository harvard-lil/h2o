<template>
	<div class="context-menu"
	     v-show="show"
	     :style="style"
	     tabindex="-1"
         @focusout="onFocusout"
	     @click="onClick">
		<slot :data="data"></slot>
	</div>
</template>

<script>
    // via https://github.com/rawilk/vue-context/blob/master/src/vue-context.vue 
	export default {
		props: {
			/**
			 * Close the menu on click.
			 *
			 * @type {boolean}
			 */
			closeOnClick: {
				type: Boolean,
				default: true
			},
			/**
			 * Close the menu automatically on window scroll.
			 *
			 * @type {boolean}
			 */
			closeOnScroll: {
				type: Boolean,
				default: true
			}
		},
		computed: {
			/**
			 * Generate the CSS styles for positioning the context menu.
			 *
			 * @returns {object|null}
			 */
			style () {
				return this.show
					? { top: `${this.top}px`, left: `${this.left}px` }
					: null;
			}
		},
		data () {
			return {
				top: null,
				left: null,
				show: false,
				data: null
			};
		},
		mounted () {
			if (this.closeOnScroll) {
				this.addScrollEventListener();
			}
		},
		beforeDestroy () {
			if (this.closeOnScroll) {
				this.removeScrollEventListener();
			}
		},
		methods: {
			/**
			 * Add scroll event listener to close context menu.
			 */
			addScrollEventListener () {
				window.addEventListener('scroll', this.close);
			},
      onFocusout (e) {
        if(e.relatedTarget != this.$el &&
           !this.$el.contains(e.relatedTarget)){
            this.close(true);
          }
        },
        /**
         * Close the context menu.
         *
         * @param {boolean|Event} emit Used to prevent event being emitted twice from when menu is clicked and closed
         */
        close (emit = true) {
          // return;
          this.top = null;
          this.left = null;
          this.data = null;
          this.show = false;
          if (emit) {
              this.$emit('close');
          }

          // call the revert element or get the id of the annotation hear and kill it 
          debugger;
        },
			/**
			 * Close the menu if `closeOnClick` is set to true.
			 */
			onClick () {
				if (this.closeOnClick) {
					this.close(false);
				}
			},
			/**
			 * Open the context menu.
			 *
			 * @param {MouseEvent} event
			 * @param {array|object|string} data User provided data for the menu
			 */
			open (event, data) {
				this.data = data;
				this.show = true;
				this.$nextTick(() => {
					this.positionMenu(event.clientY, event.clientX);
					this.$el.focus();
                    this.$emit('open', event, this.data, this.top, this.left);
				});
			},
			/**
			 * Set the context menu top and left positions.
			 *
			 * @param {number} top
			 * @param {number} left
			 */
			positionMenu (top, left) {
				const largestHeight = window.innerHeight - this.$el.offsetHeight - 25;
				const largestWidth = window.innerWidth - this.$el.offsetWidth - 25;
				if (top > largestHeight) {
					top = largestHeight;
				}
				if (left > largestWidth) {
					left = largestWidth;
				}
				this.top = top;
				this.left = left;
			},
			/**
			 * Remove the scroll event listener to close the context menu.
			 */
			removeScrollEventListener () {
				window.removeEventListener('scroll', this.close);
			}
		},
		watch: {
			/**
			 * Add or remove the scroll event listener when the prop value changes.
			 *
			 * @param {boolean} value
			 * @param {boolean} oldValue
			 */
			closeOnScroll (value, oldValue) {
				debugger;
        if (value === oldValue) {
					return;
				}
				if (value) {
					this.addScrollEventListener();
				} else {
					this.removeScrollEventListener();
				}
			}
		}
	};
</script>

<style lang="scss">
@import '../styles/vars-and-mixins';

.context-menu {
  display: block;
  margin: 0;
  padding: 0;
  position: fixed;
  z-index: 99999;
  @include sans-serif($regular, 12px, 14px);
  ul, form {
	list-style: none;
	padding: 0;
	margin: 0;
    background-color: $white;
    border: 1px solid $black;
  }
  li {
	margin: 0;
	padding: 10px 15px;
	cursor: pointer;
    white-space: nowrap;
	&:hover {
      background-color: $highlight;
	}
  }
  ul li {
    padding: 0;
  }
  a {
    display: block;
  }
  a, form {
    padding: 10px 15px;
  }
  &:focus {
    outline: none;
  }
}
</style>
