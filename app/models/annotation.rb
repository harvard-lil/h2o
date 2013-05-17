class Annotation < ActiveRecord::Base
  extend TaggingExtensions::ClassMethods
  extend RedclothExtensions::ClassMethods

  include AncestryExtensions::InstanceMethods
  include AuthUtilities

  acts_as_voteable

  acts_as_taggable_on :layers
  before_destroy :collapse_children
  has_ancestry :orphan_strategy => :restrict
  acts_as_authorization_object

  before_create :create_annotation_caches
  before_save :create_annotation_word_count_cache

  belongs_to :collage

  searchable do
    text :display_name, :boost => 2.0
    string :display_name, :stored => true
    string :id, :stored => true
    text :annotation
    string :layer_list, :multiple => true
  end

  def formatted_annotation_content
    t = Annotation.format_content(annotation)
    t.gsub(/\n/, '').gsub(/<p>/, '').gsub(/<\/p>/, '<br /><br />').gsub(/<br \/><br \/>$/, '')
  end

  validates_presence_of :annotation_start, :annotation_end
  validates_length_of :annotation, :maximum => 10.kilobytes
#  validates_numericality_of :parent_id,  :allow_nil => true

  def display_name
    owners = self.accepted_roles.find_by_name('owner')
    "On \"#{self.collage.name}\",  #{self.created_at.to_s(:simpledatetime)} #{(owners.blank?) ? '' : ' by ' + owners.users.collect{|u| u.login}.join(',')}"
  end

  alias :name :display_name
  alias :to_s :display_name

  def annotation_start_numeral
    self.annotation_start[1,self.annotation_start.length - 1]
  end

  def annotation_end_numeral
    self.annotation_end[1,self.annotation_end.length - 1]
  end

  def annotated_nodes(doc = Nokogiri::HTML.parse(self.collage.content))
    doc.xpath("//tt[starts-with(@id,'t') and substring-after(@id,'t')>='" + self.annotation_start_numeral + "' and substring-after(@id,'t')<='" + self.annotation_end_numeral + "']")
  end

  def tags
    self.layers
  end

  private

  def create_annotation_word_count_cache
    self.annotation_word_count = (self.annotation.blank?) ? 0 : self.annotation.split(/\s+/).length
  end

  def create_annotation_caches
    # No need to recreate these caches on a cloned node.
    if self.annotated_content.blank?

      # Fix annotation start/stop order.
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

end
