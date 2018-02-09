# t.integer "node_id"
# t.string "field", null: false
# t.string "value"
# t.datetime "created_at", null: false
# t.datetime "updated_at", null: false
# t.integer "casebook_id"
# t.integer "node_parent_id"
# t.integer "annotation_id"

class UnpublishedRevision < ApplicationRecord
  belongs_to :node, class_name: 'Content::Node'
  belongs_to :casebook, class_name: 'Content::Node'
  belongs_to :node_parent, class_name: 'Content::Node'
  belongs_to :annotation, class_name: 'Content::Annotation'
end

# Possibly save edited or new annotations like this: (overwrite all)
# node_id (resource_id)
# field deleted_annotation
# value annotation_id