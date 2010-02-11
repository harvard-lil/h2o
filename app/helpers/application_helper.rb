# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  def format_html(*args)
    str = RedCloth.new(args.join(' '))
    str.filter_html = true
    str.filter_styles = true
    str.filter_classes = true
    str.filter_ids = true
    str.to_html
  end

end
