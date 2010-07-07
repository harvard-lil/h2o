require 'redcloth_extensions'
class Collage < ActiveRecord::Base
  extend RedclothExtensions::ClassMethods
  include AuthUtilities
  acts_as_authorization_object

  def self.annotatable_classes
    Dir.glob(RAILS_ROOT + '/app/models/*.rb').each do |file| 
      model_name = Pathname(file).basename.to_s
      model_name = model_name[0..(model_name.length - 4)]
      model_name.camelize.constantize
    end
    # Responds to the annotatable class method with true.
    Object.subclasses_of(ActiveRecord::Base).find_all{|m| m.respond_to?(:annotatable) && m.send(:annotatable)}
  end

  def self.annotatable_classes_select_options
    self.annotatable_classes.collect{|c| [c.model_name]}
  end

  acts_as_voteable

  acts_as_category :scope => 'annotatable_id, annotatable_type'

  belongs_to :annotatable, :polymorphic => true
  has_many :annotations, :order => 'created_at'

  before_create :prepare_content

  validates_presence_of :name, :annotatable_type, :annotatable_id
  validates_length_of :name, :in => 1..250
  validates_length_of :description, :in => 1..(5.kilobytes), :allow_blank => true
  validates_length_of :content, :in => 1..(5.megabytes), :allow_blank => true

  def display_name
    "#{self.name}, #{self.created_at.to_s(:simpledatetime)} #{(self.creators.blank?) ? '' : ' by ' + self.creators.collect{|u| u.login}.join(',')}"
  end

  def layers
    self.annotations.collect{|a| a.layers}.flatten.uniq
  end

  def layer_report
    layers = {}
    self.annotations.each do |ann|
      ann.layers.each do |l|
        if layers[l.id].blank?
          layers[l.id] = {:count => 0, :name => l.name, :annotation_count => 0}
        end
        layers[l.id][:count] = layers[l.id][:count].to_i + ann.word_count
        layers[l.id][:annotation_count] = layers[l.id][:annotation_count].to_i + 1
      end
    end
    return layers
  end

  def annotatable_content
    if ! self.layers.blank?
      doc = Nokogiri::HTML.parse(self.content)
      self.annotations.each do |ann|
        layer_list = ann.layers.collect{|l| "l#{l.id}"}
        layer_list << "a#{ann.id}"
        ann.annotated_nodes(doc).each do |item|
          item['class'] = [(item['class'].blank? ? nil : item['class'].split), layer_list].flatten.compact.uniq.join(' ')
        end
      end
      doc.xpath("//html/body/*").to_s
    else
      self.content
    end
  end

  private 

  def prepare_content
    content_to_prepare = self.annotatable.content.gsub(/<br>/,'<br /> ')
    doc = Nokogiri::HTML.parse(content_to_prepare)
    doc.xpath('//*').each do |child|
      child.children.each do|c|
        if c.class == Nokogiri::XML::Text && ! c.content.blank?
          text_content = c.content.split.map{|word|"<tt>" + word + ' </tt> '}.join(' ')
          c.swap(text_content)
        end
      end
    end
    class_counter = 1
    indexable_content = []
    doc.xpath('//tt').each do |n|
      n['id'] = "t#{class_counter}"
      class_counter +=1
      indexable_content << n.text.strip
    end
    self.word_count = class_counter
    self.indexable_content = indexable_content.join(' ')
    self.content = doc.xpath("//html/body/*").to_s
  end

end
