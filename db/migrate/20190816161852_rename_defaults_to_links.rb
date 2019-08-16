class RenameDefaultsToLinks < ActiveRecord::Migration[5.2]
  def up 
    rename_table :defaults, :links

    Content::Resource.where(resource_type: "Default").map {|resource| resource.update(resource_type: "Link")}
  end

  def down
    rename_table :links, :defaults

    Content::Resource.where(resource_type: "Link").map {|resource| resource.update(resource_type: "Default")}
  end
end
