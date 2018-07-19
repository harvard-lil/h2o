# == Schema Information
#
# Table name: defaults
#
#  id                 :integer          not null, primary key
#  name               :string(1024)
#  url                :string(1024)     not null
#  description        :string(5242880)
#  public             :boolean          default(TRUE)
#  karma              :integer
#  created_at         :datetime
#  updated_at         :datetime
#  pushed_from_id     :integer
#  content_type       :string(255)
#  user_id            :integer          default(0)
#  ancestry           :string(255)
#  created_via_import :boolean          default(FALSE), not null
#

class Default < ApplicationRecord
  include MetadataExtensions
  include VerifiedUserExtensions
  include SpamPreventionExtension

  acts_as_taggable_on :tags
  belongs_to :user, optional: true
  validate :url_format
  has_ancestry :orphan_strategy => :adopt

  has_many :casebooks, inverse_of: :resource

  searchable(:include => [:metadatum, :tags]) do
    text :display_name
    string :display_name, :stored => true
    string :id, :stored => true
    text :url
    text :description
    integer :karma
    integer :user_id, :stored => true

    string :metadatum, :stored => true, :multiple => true

    string :user
    boolean :public

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

  def self.content_types_options
    %w(text audio video image other_multimedia).map { |i| [i.gsub('_', ' ').camelize, i] }
  end
end
