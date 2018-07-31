class UnpublishedRevision < ApplicationRecord
  belongs_to :node, class_name: 'Content::Node'
  belongs_to :casebook, class_name: 'Content::Node'
  belongs_to :node_parent, class_name: 'Content::Node' #annotation parent ancestor
  belongs_to :annotation, class_name: 'Content::Annotation', optional: true
end

# deleted annotation example:
# node_id: published_resource_id
# field: 'deleted_annotation'
# value: nil
# annotation_id: published_annotation_id
