class JournalArticle < ActiveRecord::Base
  include AnnotatableExtensions

  acts_as_taggable_on :tags

  has_and_belongs_to_many :journal_article_types
  has_many :collages, :as => :annotatable, :dependent => :destroy
  belongs_to :user

  validates_presence_of :name, :description, :publish_date, :author,
    :volume, :issue, :page, :bluebook_citation, :attribution

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
