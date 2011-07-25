# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def top_ancestor(klass, item)
    if !item.ancestry.nil?
      parent_id = item.ancestry.split('/').first
      klass.find(parent_id)
    else
      item
    end
  end
end
