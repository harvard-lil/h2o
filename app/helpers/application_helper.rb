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
      if row.value == 'Default'
        r_display << pluralize(row.count, 'Link')
      elsif row.value == 'TextBlock'
        r_display << pluralize(row.count, 'Text')
      else
        r_display << pluralize(row.count, row.value)
      end
    end
    r_display.join(', ')
  end
end
