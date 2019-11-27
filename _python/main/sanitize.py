import bleach
from functools import lru_cache

"""
    This file handles sanitizing user-submitted HTML, stored in ContentNode.headnote and TextBlock.content.
    During save, we pass all submitted HTML through bleach.clean(), which reformats the HTML and applies an allow-list.
    
    Our allow-list has two sources of truth for tags, attributes, and styles that should be preserved:
    
    - ones can be created by ckeditor, our frontend wysiwyg editor.
    - "legacy" ones that already exist in legacy HTML in the browser and that we don't want to strip yet.
    
    The second source could be reduced as we decide that certain things don't have to be preserved.
"""

## helpers ##

def get_words(s):
    return set(s.strip().split())


## allow-lists ##

@lru_cache()
def get_allow_lists():
    # tags created by ckeditor
    allowed_tags = get_words("""
        p br
        ol ul li
        blockquote
        strong em u s sub sup
        img
        table caption thead th tbody tr td
        hr
    """)

    # legacy tags
    allowed_tags |= get_words("""
        a address b blockquote br center cite col colgroup dd del div dl dt em h1 h2 h3 h4 h5 h6 header hr i img li mark ol 
        p pre small span strike strong sub sup table tbody td th thead time tr u ul wbr
    """)

    # attributes created by ckeditor
    # (overridden by the legacy definition, which is a super-set of this)
    # allowed_attributes = {
    #     'img': ['src', 'alt', 'style'],
    #     'table': ['cellpadding', 'cellspacing', 'align', 'border', 'style'],
    # }

    # legacy attributes
    allowed_attributes = {
        'a': {'title', 'rel', 'name', 'class', 'id', 'style', 'href'},
        'b': {'id'},
        'blockquote': {'id', 'class', 'style'},
        'br': {'class', 'style'},
        'center': {'class', 'style'},
        'col': {'width'},
        'dd': {'style'},
        'div': {'title', 'tabindex', 'dir', 'class', 'id', 'style'},
        'dl': {'style'},
        'em': {'class', 'style'},
        'h1': {'id', 'dir', 'class', 'style'},
        'h2': {'title', 'id', 'dir', 'class', 'style'},
        'h3': {'id', 'class', 'style'},
        'h4': {'class', 'style'},
        'h5': {'id', 'style'},
        'h6': {'class', 'style'},
        'header': {'class'},
        'hr': {'class', 'style'},
        'img': {'align', 'alt', 'border', 'class', 'height', 'id', 'src', 'srcset', 'style', 'tabindex', 'title', 'width'},
        'li': {'id', 'value', 'dir', 'class', 'style'},
        'ol': {'type', 'start', 'class', 'style'},
        'p': {'title', 'dir', 'class', 'id', 'lang', 'style'},
        'pre': {'id', 'style'},
        'span': {'title', 'id', 'lang', 'class', 'style'},
        'strike': {'style'},
        'strong': {'id', 'class', 'style'},
        'sup': {'id', 'class', 'style'},
        'table': {'align', 'bgcolor', 'border', 'cellpadding', 'cellspacing', 'class', 'id', 'style', 'summary', 'width'},
        'td': {'align', 'class', 'colspan', 'headers', 'id', 'rowspan', 'style', 'valign', 'width'},
        'th': {'id', 'scope'},
        'time': {'datetime', 'class'},
        'tr': {'class', 'style'},
        'u': {'class', 'style'},
        'ul': {'type', 'id', 'class', 'style'},
    }

    # styles created by ckeditor
    allowed_styles = (
        # ckeditor image tags
        get_words("border-width border-style margin float width height")
        # ckeditor table tags
        | get_words("width height")
    )

    # legacy styles
    allowed_styles |= get_words("""
         -webkit-box-shadow -webkit-text-size-adjust -webkit-transition background background-attachment background-clip 
         background-color background-image background-origin background-position background-repeat background-size border 
         border-bottom border-bottom-color border-bottom-left-radius border-bottom-right-radius border-bottom-style 
         border-bottom-width border-collapse border-color border-left border-left-color border-left-style border-left-width 
         border-right border-right-color border-right-style border-right-width border-style border-top border-top-color 
         border-top-left-radius border-top-right-radius border-top-style border-top-width border-width bottom box-sizing 
         clear clip color counter-increment counter-reset cursor direction display float font font-family font-size 
         font-size-adjust font-stretch font-style font-variant font-variant-caps font-variant-ligatures font-variant-numeric 
         font-weight height left letter-spacing line-height list-style list-style-image list-style-position list-style-type 
         margin margin-bottom margin-left margin-right margin-top max-width orphans outline outline-color outline-style 
         outline-width overflow padding padding-bottom padding-left padding-right padding-top page page-break-after 
         page-break-before position quotes right text-align text-decoration text-decoration-color text-decoration-style 
         text-indent text-justify text-rendering text-transform top transition unicode-bidi vertical-align white-space 
         widows width word-break word-spacing word-wrap z-index
    """)

    return allowed_tags, allowed_attributes, allowed_styles


def sanitize(html):
    """
        Remove non-allowed tags, attributes, and styles.

        Strip unknown tags:
        >>> assert sanitize('<p><foo>abc <br> def</foo></p>') == '<p>abc <br> def</p>'

        Strip unknown attributes:
        >>> assert sanitize('<a href="ok.html" bad="bad">foo</a>') == '<a href="ok.html">foo</a>'

        Strip javascript:
        >>> assert sanitize('<a href="javascript:foo">foo</a>') == '<a>foo</a>'

        Strip unknown styles:
        >>> assert sanitize('<p style="margin: 10px; foo: bar;">abc</p>') == '<p style="margin: 10px;">abc</p>'
    """
    allowed_tags, allowed_attributes, allowed_styles = get_allow_lists()
    out = bleach.clean(html, tags=allowed_tags, attributes=allowed_attributes, styles=allowed_styles, strip=True)

    # bleach currently doubles '<wbr>' into '<wbr></wbr>'. work around that edge case until we drop support for <wbr>
    # or bleach is fixed. see https://github.com/mozilla/bleach/issues/488
    out = out.replace('<wbr></wbr>', '<wbr>')

    return out