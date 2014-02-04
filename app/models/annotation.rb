class Annotation < ActiveRecord::Base
  extend TaggingExtensions::ClassMethods
  extend RedclothExtensions::ClassMethods

  include AuthUtilities

  acts_as_taggable_on :layers
  acts_as_authorization_object
  belongs_to :linked_collage, :class_name => "Collage", :foreign_key => "linked_collage_id"

  belongs_to :collage
  belongs_to :user

  def formatted_annotation_content
    t = Annotation.format_content(annotation)
    t.gsub(/\n/, '').gsub(/<p>/, '').gsub(/<\/p>/, '<br /><br />').gsub(/<br \/><br \/>$/, '')
  end

  validates_presence_of :annotation_start, :annotation_end
  validates_length_of :annotation, :maximum => 10.kilobytes

  def display_name
    "On \"#{self.collage.name}\",  #{self.created_at.to_s(:simpledatetime)} by " + self.user.login
  end

  alias :name :display_name
  alias :to_s :display_name

  def annotated_nodes(doc = Nokogiri::HTML.parse(self.collage.content))
    doc.xpath("//tt[starts-with(@id,'t') and substring-after(@id,'t')>='" + self.annotation_start_numeral + "' and substring-after(@id,'t')<='" + self.annotation_end_numeral + "']")
  end

  def tags
    self.layers
  end
end
