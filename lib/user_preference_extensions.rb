module UserPreferenceExtensions
  extend ActiveSupport::Concern

  def apply_user_preferences(user, on_create, options={})
    return unless user

    # The special handling here allows cookies coming from playlist exporter to
    # override whatever is in the database for this user.
    common_user_preference_attrs.each do |attr|
      if options[:force_overwrite]
        cookie_value = user.send(attr)
      else
        # Exports may have some cookies defined at this point. Those take precedence.
        # Use of .to_s is extra defensive approach to handling cookies with a boolean
        # false value. It's possible it's not actually needed.
        cookie_value = cookies[attr].to_s.present? ? cookies[attr] : user.send(attr)
      end
      cookies[attr] = cookie_value
    end

    # cookies[:bookmarks] = on_create ? "[]" : user.bookmarks_map.to_json
  end

  def destroy_user_preferences
    #TODO: We don't use print_dates_details anymore, so we can drop the column from the DB
    names = [:bookmarks, :print_dates_details] + common_user_preference_attrs
    names.each do |attr|
      cookies.delete(attr)
    end
  end


  private

  def common_user_preference_attrs
    [
      :user_id,
      :default_font_size, :default_font, :tab_open_new_items, :simple_display,
      :print_titles, :toc_levels, :print_paragraph_numbers, :print_annotations,
      :print_highlights, :print_font_face, :print_font_size, :default_show_comments,
      :default_show_paragraph_numbers, :hidden_text_display, :print_links, :print_export_format,
    ]
  end

end
