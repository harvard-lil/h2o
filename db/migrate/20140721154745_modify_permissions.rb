class ModifyPermissions < ActiveRecord::Migration
  def change
    connection.execute("DELETE FROM permissions; DELETE FROM permission_assignments;")
    Permission.create({ :key => "edit_playlist", :label => "Edit", :permission_type => "playlist" })
    Permission.create({ :key => "view_private_playlist", :label => "View Private", :permission_type => "playlist" })
    Permission.create({ :key => "edit_collage", :label => "Edit", :permission_type => "collage" })
    Permission.create({ :key => "view_private_collage", :label => "View Private", :permission_type => "collage" })
  end
end
