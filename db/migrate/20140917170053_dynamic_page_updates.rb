class DynamicPageUpdates < ActiveRecord::Migration
  def change
    add_column :pages, :footer_link, :boolean, :null => false, :default => false
    add_column :pages, :footer_link_text, :string
    add_column :pages, :footer_sort, :integer, :null => false, :default => 1000
    add_column :pages, :is_user_guide, :boolean, :null => false, :default => false
    add_column :pages, :user_guide_sort, :integer, :null => false, :default => 1000
    add_column :pages, :user_guide_link_text, :string

    Page.where(slug: "about").first.update_attributes({ :footer_link => true, :footer_sort => 1 })
    Page.where(slug: "overview_help").first.update_attributes({ :footer_link_text => "User Guide", :footer_link => true, :footer_sort => 2, :is_user_guide => true, :user_guide_sort => 1, :user_guide_link_text => "Overview" })
    Page.where(slug: "faq").first.update_attributes({ :footer_link => true, :footer_sort => 3, :footer_link_text => "FAQS" }) 
    Page.where(slug: "terms").first.update_attributes({ :footer_link => true, :footer_sort => 4, :footer_link_text => "Terms of Service" }) 
    Page.where(slug: "privacy").first.update_attributes({ :footer_link => true, :footer_sort => 5, :footer_link_text => "Privacy Policy" }) 
    Page.where(slug: "team").first.update_attributes({ :footer_link => true, :footer_sort => 6, :footer_link_text => "H2O Team" }) 
    Page.where(slug: "contact_us").first.update_attributes({ :footer_link => true, :footer_sort => 7, :footer_link_text => "Contact Us" }) 

    Page.where(slug: "create_account_help").first.update_attributes({ :is_user_guide => true, :user_guide_sort => 2, :user_guide_link_text => "Creating an account" })
    Page.where(slug: "dashboard_help").first.update_attributes({ :is_user_guide => true, :user_guide_sort => 3, :user_guide_link_text => "Dashboard" })
    Page.where(slug: "playlists_help").first.update_attributes({ :is_user_guide => true, :user_guide_sort => 4, :user_guide_link_text => "Playlists" })
    Page.where(slug: "collages_help").first.update_attributes({ :is_user_guide => true, :user_guide_sort => 5, :user_guide_link_text => "Collages" })
    Page.where(slug: "cases_help").first.update_attributes({ :is_user_guide => true, :user_guide_sort => 6, :user_guide_link_text => "Cases" })
    Page.where(slug: "media_help").first.update_attributes({ :is_user_guide => true, :user_guide_sort => 7, :user_guide_link_text => "Media: audio images, PDFs, and video" })
    Page.where(slug: "links_help").first.update_attributes({ :is_user_guide => true, :user_guide_sort => 8, :user_guide_link_text => "Links" })
    Page.where(slug: "printing_help").first.update_attributes({ :is_user_guide => true, :user_guide_sort => 9, :user_guide_link_text => "Printing" })
    Page.where(slug: "glossary_help").first.update_attributes({ :is_user_guide => true, :user_guide_sort => 10, :user_guide_link_text => "Glossary" })
  end
end
