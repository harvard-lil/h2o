require 'tagging_extensions'

class Annotation < ActiveRecord::Base
  extend TaggingExtensions::ClassMethods
  include TaggingExtensions::InstanceMethods

  acts_as_voteable
  acts_as_category :scope => :collage_id
  acts_as_taggable_on :layers

  acts_as_authorization_object

  belongs_to :user
  belongs_to :collage

  validates_presence_of :annotation_start, :annotation_end
  validates_length_of :annotation, :maximum => 10.kilobytes
  validates_numericality_of :parent_id, :children_count, :ancestors_count, :descendants_count, :position, :allow_nil => true

  def annotation_start_numeral
    self.annotation_start[1,self.annotation_start.length - 1]
  end

  def annotation_end_numeral
    self.annotation_end[1,self.annotation_end.length - 1]
  end

  def annotated_nodes(doc = Nokogiri::HTML.parse(self.collage.annotatable.content))
    doc.xpath("//tt[starts-with(@id,'t') and substring-after(@id,'t')>='" + self.annotation_start_numeral + "' and substring-after(@id,'t')<='" + self.annotation_end_numeral + "']")
  end

  def annotated_content
    output = ''
    self.annotated_nodes.each do |item|
      output += "#{item.inner_html} "
    end
    output
  end

end
