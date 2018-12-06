class TextBlock < ApplicationRecord

  # NOTE: This absolutely must be called before all the includes below. If you
  #   put it below them, you will get an ActiveRecord::RecordNotDestroyed
  #   exception when destroying a text block in some scenarios.
  include MetadataExtensions
  include Rails.application.routes.url_helpers
  include VerifiedUserExtensions

  acts_as_taggable_on :tags

  belongs_to :user, optional: true

  has_many :casebooks, inverse_of: :contents, class_name: 'Content::Casebook', foreign_key: :resource_id

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

  def title
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

  searchable(:include => [:metadatum, :tags]) do
    text :display_name, :boost => 3.0
    string :display_name, :stored => true
    string :id, :stored => true
    text :clean_content
    boolean :public

    string :user
    string :user_display, :stored => true
    integer :user_id, :stored => true

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

  def has_casebooks?
    Content::Resource.where(resource_id: self.id).where.not(casebook_id: nil).present?
  end

  def associated_casebooks
    casebook_ids = Content::Resource.where(resource_id: self.id).where.not(casebook_id: nil).pluck(:casebook_id)
    Content::Casebook.where(id: casebook_ids).select(:id, :title)
  end
end
