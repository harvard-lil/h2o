DEFAULT_TIMEZONE = 'Eastern Time (US & Canada)'

# UPGRADE TODO
#Formtastic::SemanticFormBuilder.escape_html_entities_in_hints_and_labels = false
#yes, this is probably too coarse.

WHITELISTED_TAGS = %w|a b br center del div em h1 h2 h3 h4 h5 h6 i img li ol p strike strong u ul blockquote span|
WHITELISTED_ATTRIBUTES = %w|class src href height width target title|

require 'dropbox_sdk'

H2O_CACHE_COMPRESSION = true
