class JournalArticle < ActiveRecord::Base
  extend RedclothExtensions::ClassMethods
  extend TaggingExtensions::ClassMethods

  include H2oModelExtensions
  # include AnnotatableExtensions
  # include PlaylistableExtensions
  include AuthUtilities
  #include MetadataExtensions

  acts_as_authorization_object
  acts_as_taggable_on :tags

  belongs_to :journal_article_type
end
