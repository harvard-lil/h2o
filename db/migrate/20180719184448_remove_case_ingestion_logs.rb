class RemoveCaseIngestionLogs < ActiveRecord::Migration[5.1]
  def up
    drop_table :case_ingestion_logs
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
