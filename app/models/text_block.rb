# == Schema Information
#
# Table name: text_blocks
#
#  id                 :integer          not null, primary key
#  name               :string(255)      not null
#  content            :string(5242880)  not null
#  public             :boolean          default(TRUE)
#  created_at         :datetime
#  updated_at         :datetime
#  karma              :integer
#  pushed_from_id     :integer
#  user_id            :integer          default(0), not null
#  created_via_import :boolean          default(FALSE), not null
#  description        :string(5242880)
#  version            :integer          default(1), not null
#  enable_feedback    :boolean          default(TRUE), not null
#  enable_discussions :boolean          default(FALSE), not null
#  enable_responses   :boolean          default(FALSE), not null
#

class TextBlock < ApplicationRecord

  # NOTE: This absolutely must be called before all the includes below. If you
  #   put it below them, you will get an ActiveRecord::RecordNotDestroyed
  #   exception when destroying a text block in some scenarios.
  has_many :collages, :dependent => :destroy, :as => :annotatable

  include StandardModelExtensions
  include AnnotatableExtensions
  include MetadataExtensions
  include Rails.application.routes.url_helpers
  include CaptchaExtensions
  include VerifiedUserExtensions
  include DeletedItemExtensions

  RATINGS_DISPLAY = {
    :collaged => "Annotated",
    :bookmark => "Bookmarked",
    :add => "Added to"
  }

  acts_as_taggable_on :tags

  has_many :defects, :as => :reportable
  has_many :playlist_items, :as => :actual_object
  has_many :frozen_items, :as => :item
  has_many :annotations, -> { order(:created_at) }, :dependent => :destroy, :as => :annotated_item
  has_many :responses, -> { order(:created_at) }, :dependent => :destroy, :as => :resource
  belongs_to :user

  validates_presence_of :name

  def self.tag_list
    Tag.find_by_sql("SELECT ts.tag_id AS id, t.name FROM taggings ts
      JOIN tags t ON ts.tag_id = t.id
      WHERE taggable_type = 'TextBlock'
      GROUP BY ts.tag_id, t.name
      ORDER BY COUNT(*) DESC LIMIT 25")
  end

  def deleteable_tags
    []
  end

  def display_name
    name
  end

  #Export the content that gets annotated in a Collage - also, render the content for display.
  #As always, the content method should export valid html/XHTML.
  def sanitized_content
    ActionController::Base.helpers.sanitize(
      self.content,
      :tags => WHITELISTED_TAGS + ["sup", "sub", "pre"],
      :attributes => WHITELISTED_ATTRIBUTES + ["style", "name"]
    )
  end

  alias :to_s :display_name

  searchable(:include => [:metadatum, :collages, :tags]) do
    text :display_name, :boost => 3.0
    string :display_name, :stored => true
    string :id, :stored => true
    text :clean_content
    boolean :public
    integer :karma

    string :user
    string :user_display, :stored => true
    integer :user_id, :stored => true

    string :tag_list, :stored => true, :multiple => true
    string :collages, :stored => true, :multiple => true
    string :metadatum, :stored => true, :multiple => true

    time :created_at
    time :updated_at

    string :klass, :stored => true
    boolean :primary do
      false
    end
    boolean :secondary do
      false
    end
  end

  def clean_content
    self.content.gsub!(/\p{Cc}/, "")
  end

  def barcode
    Rails.cache.fetch("textblock-barcode-#{self.id}", :compress => H2O_CACHE_COMPRESSION) do
      barcode_elements = self.barcode_bookmarked_added
      self.collages.each do |collage|
        barcode_elements << { :type => "collaged",
                              :date => collage.created_at,
                              :title => "Annotated to #{collage.name}",
                              :link => collage_path(collage),
                              :rating => 5 }
      end

      value = barcode_elements.inject(0) { |sum, item| sum + item[:rating] }
      self.update_attribute(:karma, value)

      barcode_elements.sort_by { |a| a[:date] }
    end
  end

  def h2o_clone(new_user, params)
    text_copy = self.dup
    text_copy.karma = 0
    text_copy.name = params[:name] if params.has_key?(:name)
    text_copy.description = params[:description] if params.has_key?(:description)
    text_copy.user = new_user
    text_copy
  end

  def printable_content
    doc = Nokogiri::HTML.fragment(self.content)
    doc.css("p").add_class("Item-text")
    doc.to_html
  end


end
