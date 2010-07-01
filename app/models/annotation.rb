require 'tagging_extensions'
require 'redcloth_extensions'

class Annotation < ActiveRecord::Base
  include AuthUtilities
  extend TaggingExtensions::ClassMethods
  include TaggingExtensions::InstanceMethods
  extend RedclothExtensions::ClassMethods

  acts_as_voteable
  acts_as_category :scope => :collage_id
  acts_as_taggable_on :layers

  acts_as_authorization_object

  before_create :create_annotation_caches

  belongs_to :collage

  validates_presence_of :annotation_start, :annotation_end
  validates_length_of :annotation, :maximum => 10.kilobytes
  validates_numericality_of :parent_id, :children_count, :ancestors_count, :descendants_count, :position, :allow_nil => true

  def display_name
    owners = self.accepted_roles.find_by_name('owner')
    "On \"#{self.collage.name}\",  #{self.created_at.to_s(:simpledatetime)} #{(owners.blank?) ? '' : ' by ' + owners.users.collect{|u| u.login}.join(',')}"
  end

  def annotation_start_numeral
    self.annotation_start[1,self.annotation_start.length - 1]
  end

  def annotation_end_numeral
    self.annotation_end[1,self.annotation_end.length - 1]
  end

  def annotated_nodes(doc = Nokogiri::HTML.parse(self.collage.content))
    doc.xpath("//tt[starts-with(@id,'t') and substring-after(@id,'t')>='" + self.annotation_start_numeral + "' and substring-after(@id,'t')<='" + self.annotation_end_numeral + "']")
  end

  def create_annotation_caches
    # Fix node order.
    nodes = [self.annotation_start_numeral.to_i, self.annotation_end_numeral.to_i].sort.collect{|n| "t#{n}"}
    self.annotation_start = nodes[0]
    self.annotation_end = nodes[1]

    output = ''
    anodes = self.annotated_nodes
    anodes.each do |item|
      output += "#{item.inner_html} "
    end
    self.annotated_content = output
    self.word_count = anodes.length
  end

end
