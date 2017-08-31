# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def footer_links
    Rails.cache.fetch('footer-links') do
      Page.where(:footer_link => true).order(:footer_sort)
    end
  end

  def help_links
    Rails.cache.fetch('help-links') do
      Page.where(:is_user_guide => true).order(:user_guide_sort)
    end
  end
end
