<template>
  <div class="two-panel">
    <div class="left-panel">
      <editor
        ref="outliner"
            :init="tinyMCEInitConfig"
        />
    </div>
    <!-- <div class="right-panel"> -->
    <!--   <div id="table-of-contents"> -->
    <!--     <the-table-of-contents -->
    <!--         :casebook="casebook" -->
    <!--         :root-id="rootId" -->
    <!--         :editing="editing" -->
    <!--         :root-ordinals="rootOrdinals"> -->
    <!--     </the-table-of-contents> -->
    <!--   </div> -->
    <!-- </div> -->
  </div>
</template>
                                
<script>
import Editor from '@tinymce/tinymce-vue';
//import TheTableOfContents from "../components/TheTableOfContents";
import pp from 'libs/text_outline_parser'; 
import tinymce from 'tinymce/tinymce'; // eslint-disable-line no-unused-vars
import 'tinymce/themes/silver';
import 'tinymce/plugins/link';
import 'tinymce/plugins/lists';
import 'tinymce/plugins/image';
import 'tinymce/plugins/table';
import 'tinymce/plugins/code';
import 'tinymce/plugins/paste';


export default {
components: {
editor: Editor
//    TheTableOfContents
},
data: () => ({
tinyMCEInitConfig: {
plugins: 'lists paste',
skin_url: '/static/tinymce_skin',
menubar: false,
branding: false,
toolbar: 'undo redo | numlist indent outdent | paste',
valid_elements: 'div,ol,li,span',
paste_preprocess: function(plugin, args) {
let text = args.content.replace(/&lt;p&gt;|<p>/g, "").replace(/&lt;\/p&gt;|<\/p>/g, "\n").replace(/$lt;br *\/&gt;/g,"\n").replace(/<br *\/>/g,"\n");
let parsed = pp.parsePaste(text);
let nestedList = pp.toNestedList(parsed);
args.content = nestedList;
},
paste_postprocess: function(plugin, args) {
console.log(args);
},
paste_word_valid_elements: 'div,ol,li,span',
paste_enable_default_filters: false,
paste_as_text: true
}
}),
directives: {
},
computed: {
},
methods: {
  },
props: ["casebook", "rootId", "editing", "rootOrdinals"],
mounted: function() {
}
};
</script>

<style lang="scss">
@import "../styles/vars-and-mixins";

.two-panel {
    display:flex;
    flex-direction:row;
    max-width:90%;
    margin: 0px auto;
    border-left: 1px solid grey;
    border-right: 1px solid grey;
    .left-panel {
        margin-right:10px;
        width:75%;
    }
    .right-panel {
        margin-left:10px;
    }
}

#table-of-contents {
    > .table-of-contents > .nestable > ol {
        > li.nestable-item > .nestable-item-content {
            > .listing-wrapper > .listing.resource {
                padding-left: 60px;
            }
            > div > .listing-wrapper > .listing.resource {
                padding-left: 60px;
            }
        }
    }
    ol {
        counter-reset: item;
    }
    li {
        counter-increment: item;
        display: block;
    }
    button.action-expand {
        border: 0 solid transparent;
        background: transparent;
    }
    .no-collapse-padded {
        width: 32px;
        height: 32px;
        margin: 4px 7px;
    }
    .nestable-item {
        position: relative;
        .actions {
            position: absolute;
            top: -6px;
            right: 0;
            height: 100%;
            margin-top: 6px;
            display: flex;
            flex-direction: column;
            align-content: center;
            justify-content: center;
        }
    }
    .action-confirmation {
        display: flex;
        flex-direction: row;
        justify-content: space-between;
        padding-right: 10px;
        button {
            width: unset;
            height: unset;
            color: unset;
            background-color: unset;
            display: unset;
            margin: unset;
            background-position: unset;
            background-repeat: unset;
            background-size: unset;
            font-weight: 400;
            margin: 2px;
            padding: 6px 16px;
        }
        .action-confirm-delete {
            background-color: $light-blue;
            color: $white;
        }
        .action-cancel-delete {
            background-color: $white;
            color: $black;
        }
    }
    li.nestable-item.is-dragging {
        border: 4px dashed grey;
        border-radius: 8px;
        margin-top: 8px;
        margin-bottom: 8px;
        .listing {
            margin-top: 0px;
            &.section:hover,
            &.section:focus-within {
                background-color: $black;
                .section-number,
                .section-title {
                    color: $white;
                }
            }
            &.resource:hover,
            &.resource:focus-within {
                background-color: $white;
                .resource-case,
                .resource-date,
                .section-number,
                .section-title {
                    color: $black;
                }
            }
        }
    }
    .listing-wrapper.delete-confirm .listing {
        padding-right: 168px;
    }
    .listing {
        display: block;
        width: 100%;
        padding: 12px 16px;
        padding-right: 42px;
        margin-top: 6px;
        border: 1px solid $black;
        
        &.section {
            display: flex;
            flex-direction: column;
            align-items: left;
            background-color: $black;
            
            @media (max-width: $screen-xs) {
                flex-direction: row;
            }
            
            .section-title {
                display: inline;
                font-weight: $medium;
            }
            .section-number,
            .section-title {
                color: $white;
                margin-right: 10px;
            }
        }
        &.resource {
            background-color: $white;
            display: grid;
            grid-template-columns: auto 1fr 15%;
            
            @media (max-width: $screen-xs) {
                .resource-container {
                    margin: 0 9px;
                }
            }
            
            .section-title {
                display: inline;
            }
            
            .case-section-title {
                margin-bottom: 4px;
            }
            
            .section-number,
            .section-title {
                color: $black;
            }
            
            .case-metadata-container {
                display: flex;
                align-items: center;
                
                @media (max-width: $screen-xxs) {
                    flex-direction: column;
                    align-items: flex-start;
                }
                
                .resource-case:empty {
                    display: none;
                }
                
                .resource-case {
                    margin-right: 9px;
                }
            }
            
            .resource-type-container {
                display: flex;
                align-items: center;
                justify-content: flex-end;
                
                @media (max-width: $screen-xs) {
                    margin-right: -4px;
                    
                    .resource-type {
                        padding: 2px 7px;
                    }
                }
            }
        }
        &.empty {
            border: 1px dashed $gray;
            text-align: center;
            color: $dark-gray;
            background: transparent;
            padding: 60px;
        }
        &.section:hover,
        &.section:focus,
        &.section:focus-within,
        &.resource:hover,
        &.resource:focus,
        &.resource:focus-within {
            outline: 2px solid $white;
            background-color: $light-blue;
            border-color: $light-blue;
            * {
                color: $white;
                border-color: $white;
            }
            *:focus {
                outline: 2px solid $white;
                outline-offset: 2px;
            }
        }
        @media (max-width: $screen-xs) {
            &.section,
            &.resource {
                div {
                    margin: 4px 0;
                    padding-left: 0;
                    text-align: left;
                }
            }
        }
        @media (min-width: $screen-xs) {
            &.section {
                flex-direction: row;
                align-items: center;
            }
        }
        
        .section-number,
        .section-number:after{
            font-size: 12px;
            display: flex;
            align-items: center;
            margin-right: 10px;
        }
        .section-number:after {
            content: counters(item, ".") " ";
        }
        .section-title {
            @include sans-serif($bold, 14px, 14px);
            display: inline-block;
        }
        .resource-type,
        .resource-case,
        .resource-date {
            @include sans-serif($light, 14px, 14px);
            display: inline-block;
            
            text-align: left;
            color: $black;
        }
        
        .resource-type {
            border: 1px solid $light-blue;
            color: $light-blue;
            display: flex;
            justify-content: center;
            align-items: center;
            font-size: 12px;
            font-weight: bold;
            height: 20px;
            width: 72px;
        }
    }
    &.confirm-delete {
        margin-right: 160px;
    }
    ol.nestable-list.nestable-group {
        padding-left: 0px;
    }
    .nestable-list {
        .nestable-list {
            border-left: 8px solid $light-blue;
            padding-left: 16px;
            margin-left: 30px;
        }
    }
    div.editable .nestable-list .nestable-list {
        border-left: 8px solid $yellow;
        padding-left: 16px;
        margin-left: 30px;
    }
    .nestable-drag-layer {
        opacity: 0.7;
        position: fixed;
        top: 0;
        left: 0;
        z-index: 100;
        pointer-events: none;
        .listing {
            .section-number:before {
                content: "-";
      }
    }
  }
}
</style>
