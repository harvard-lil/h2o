class UnpublishedRevision < ApplicationRecord
  belongs_to :node, class_name: 'Content::Node'
end