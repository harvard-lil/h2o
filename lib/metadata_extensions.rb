module MetadataExtensions
  extend ActiveSupport::Concern

  included do
    has_one :metadatum, :as => :classifiable, :dependent => :destroy
    accepts_nested_attributes_for :metadatum,
      :allow_destroy => true,
      :reject_if => :all_blank
  end
end
