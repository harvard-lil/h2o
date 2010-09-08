# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  def display_tree(parent,output)
    c = Collage.find(parent)
    output += '<ul>'
    output += %Q|<li>#{link_to(c.display_name,c)}</li>|
    c.children.each do |n|
      output += %Q|<li>#{link_to(n.display_name,n)}</li>|
      display_tree(n,output)
    end
    output += '</ul>'
  end

  def display_tree_recursive(tree, parent_id)
    ret = "\n<ul id='node_#{parent_id}'>"
    tree.children.each do |node|
      if node.parent_id == parent_id
        ret += "\n\t<li>"
        ret += yield node
        ret += display_tree_recursive(node, node.parent_id) { |n| yield n } unless node.children.empty?
        ret += "\t</li>\n"
      else
        ret += yield node
      end
    end
    ret += "</ul>\n"
  end

end
