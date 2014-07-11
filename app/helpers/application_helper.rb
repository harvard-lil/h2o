# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def item_date_stamp(item)
     if params[:controller] == 'users'
      item.updated_at
    else
      item.created_at
    end.strftime("%m/%d/%Y")
  end

  def results_display(collection, klass_facets)
    return pluralize(collection.results.total_entries, 'Result') if klass_facets.nil?

    r_display = []
    klass_facets.each do |row|
      r_display << pluralize(row.count, row.value)
    end
    r_display.join(', ')
  end
end
