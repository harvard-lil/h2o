class VersionsController < ApplicationController

  def show
    self.send("add_#{base_name}_assets")
    instance_variable_set("@#{base_name}", parent_class.copy_by_id_and_version(params[parent_param_key], params[:id]))
    render "#{base_name.pluralize}/show"
  end
  
  def parent_param_key
    params.keys.detect{|k| k.match('_id')}
  end
  
  def parent_class
    base_name.capitalize.constantize
  end
  
  def base_name
    parent_param_key.gsub("_id", '')
  end
  
end
