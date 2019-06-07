class UnpublishedRevision < ApplicationRecord
  belongs_to :node, class_name: 'Content::Node'
  belongs_to :casebook, class_name: 'Content::Node'
  belongs_to :node_parent, class_name: 'Content::Node' #annotation parent ancestor
  belongs_to :annotation, class_name: 'Content::Annotation', optional: true
end
