class JournalArticle < ActiveRecord::Base
  extend RedclothExtensions::ClassMethods
  extend TaggingExtensions::ClassMethods

  include H2oModelExtensions
  include AnnotatableExtensions
  include AuthUtilities

  acts_as_authorization_object
  acts_as_taggable_on :tags

  has_and_belongs_to_many :journal_article_types
  has_many :collages, :as => :annotatable, :dependent => :destroy

  validates_presence_of :name, :description, :publish_date, :author,
    :volume, :issue, :page, :bluebook_citation, :attribution

  searchable(:include => [:collages, :tags]) do
    text :name, :boost => 3.0
    string :name, :stored => true
    string :display_name, :stored => true

    string :id, :stored => true
    text :description
    boolean :active
    boolean :public

    #string :author
    string :tag_list, :stored => true, :multiple => true
    string :collages, :stored => true, :multiple => true
  end

  def display_name
    self.name + (self.subtitle.present? ? ": #{self.subtitle}" : '')
  end

  def article_type
    if self.journal_article_types.any?
      self.journal_article_types.collect { |b| b.name }.join(', ')
    else
      return nil
    end
  end
end
