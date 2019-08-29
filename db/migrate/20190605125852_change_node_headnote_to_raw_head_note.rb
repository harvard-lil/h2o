class ChangeNodeHeadnoteToRawHeadNote < ActiveRecord::Migration[5.2]
  def up
    rename_column :content_nodes, :headnote, :raw_headnote
    add_column :content_nodes, :headnote, :text

    Content::Node.where.not(raw_headnote: nil).find_each do |node|
      node.update headnote: node.raw_headnote
    end
  end

  def down
    remove_column :content_nodes, :headnote
    rename_column :content_nodes, :raw_headnote, :headnote
  end
end
