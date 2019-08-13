class TextBlock < ApplicationRecord
  include ContentAnnotatable

  # NOTE: This absolutely must be called before all the includes below. If you
  #   put it below them, you will get an ActiveRecord::RecordNotDestroyed
  #   exception when destroying a text block in some scenarios.
  include Rails.application.routes.url_helpers

  belongs_to :user, optional: true
  has_many :casebooks, inverse_of: :contents, class_name: 'Content::Casebook', foreign_key: :resource_id

  validates_presence_of :name

  def display_name
    name
  end

  def title
    name
  end

  alias :to_s :display_name

  searchable do
    text :display_name, :boost => 3.0
    string :display_name, :stored => true
    string :id, :stored => true
    text :clean_content
    boolean :public

    string :user
    string :user_display, :stored => true
    integer :user_id, :stored => true

    time :created_at
    time :updated_at

    string :klass, :stored => true
  end

  def clean_content
    self.content.gsub!(/\p{Cc}/, "")
  end

  def associated_resources
    links = ""
    resources = Content::Resource.where(resource_type: self.class.name, resource_id: self.id)
    resources.each do |resource|
      casebook = resource.casebook
      links += "<div><a href=#{resource_path(casebook, resource)}>#{html_escape(casebook.title)} [#{casebook.created_at.year}] - #{html_escape(casebook.owner)}</a></div>".html_safe
    end
    links.html_safe
  end
end
