class EnableBtreeGinIndex < ActiveRecord::Migration[5.1]
  def up
    execute 'CREATE EXTENSION btree_gin;'
  end
  def down
    execute 'DROP EXTENSION btree_gin;'
  end
end
