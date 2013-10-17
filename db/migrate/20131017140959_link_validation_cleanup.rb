class LinkValidationCleanup < ActiveRecord::Migration
  def self.up
    conxn = ActiveRecord::Base.connection
    conxn.execute("UPDATE defaults SET url = 'http://' || url || '/' WHERE url NOT LIKE 'http%' AND url NOT LIKE 'ftp:%'")
  end

  def self.down
    # no reverse
  end
end
