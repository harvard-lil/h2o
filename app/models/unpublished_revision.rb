# t.integer "node_id"
# t.string "field", null: false
# t.string "value", null: false
# t.datetime "created_at", null: false
# t.datetime "updated_at", null: false
# t.bigint "casebook_id"
# t.index ["node_id", "field"], name: "index_unpublished_revisions_on_node_id_and_field"

class UnpublishedRevision < ApplicationRecord
  belongs_to :node, class_name: 'Content::Node'
end

# Possibly save edited or new annotations like this: (overwrite all)
# node_id (resource_id)
# field deleted_annotation
# value annotation_id