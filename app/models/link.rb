class Link < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :user, optional: true
  validate :url_format
  has_ancestry :orphan_strategy => :adopt

  has_many :casebooks, inverse_of: :contents, class_name: 'Content::Casebook', foreign_key: :resource_id

  searchable do
    text :display_name
    string :display_name, :stored => true
    string :id, :stored => true
    text :url
    text :description
    integer :user_id, :stored => true

    string :user
    boolean :public

    time :created_at
    time :updated_at

    string :klass, :stored => true
  end

  def url_format
    self.errors.add(:url, "must be an absolute path (it must contain http)") if !self.url.to_s.match(/^http/)
  end

  def content_type
    super || 'html'
  end

  def display_name
    self.name || "Link to #{URI::parse(self.url).host}"
  end

  def title
    display_name
  end

  def associated_resources
    links = ""
    resources = Content::Resource.where(resource_type: self.class.name, resource_id: self.id)
    resources.each do |resource|
      casebook = resource.casebook
      links += "<div><a href=#{resource_path(casebook, resource)}>#{casebook.title} [#{casebook.created_at.year}] - #{casebook.owner}</a></div>"
    end
    links.html_safe
  end
end
