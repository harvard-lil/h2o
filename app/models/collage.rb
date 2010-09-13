require 'redcloth_extensions'
require 'playlistable_extensions'

class Collage < ActiveRecord::Base
  extend PlaylistableExtensions::ClassMethods
  extend RedclothExtensions::ClassMethods

  include PlaylistableExtensions::InstanceMethods
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

  acts_as_category :collapse_children => true

  belongs_to :annotatable, :polymorphic => true
  has_many :annotations, :order => 'created_at'

  before_create :prepare_content

  validates_presence_of :name, :annotatable_type, :annotatable_id
  validates_length_of :name, :in => 1..250
  validates_length_of :description, :in => 1..(5.kilobytes), :allow_blank => true
  validates_length_of :content, :in => 1..(5.megabytes), :allow_blank => true

  def fix_children
    logger.warn 'I just got called. Airbag saved my life'
    self.children.each do |child|
      #collapse children to the parent of the collage being destroyed.
      child.parent = self.parent
    end
  end

  def fork_it(new_user)
    collage_copy = self.clone
    collage_copy.name = "#{self.name} copy"
    collage_copy.created_at = Time.now
    collage_copy.parent = self
    collage_copy.save!
    collage_copy.accepts_role!(:owner, new_user)
    collage_copy.accepts_role!(:creator, new_user)
    collage_copy.accepts_role!(:owner, new_user)
    collage_copy.accepts_role!(:creator, new_user)
    self.creators.each do|c|
      collage_copy.accepts_role!(:original_creator,c)
    end
    self.annotations.each do |annotation|
      new_annotation = annotation.clone
      #copy tags
      new_annotation.layer_list = annotation.layer_list
      new_annotation.accepts_role!(:creator, new_user)
      new_annotation.accepts_role!(:owner, new_user)
      new_annotation.parent = annotation
      annotation.creators.each do|c|
        new_annotation.accepts_role!(:original_creator, c)
      end
      collage_copy.annotations << new_annotation
      collage_copy.save!
    end
    collage_copy
  end

  def can_edit?
    return self.owner? || self.admin? || current_user.has_role?(:collages_admin) || current_user.has_role?(:superadmin)
  end

  def display_name
    "#{self.name}, #{self.created_at.to_s(:simpledatetime)}#{(self.creators.blank?) ? '' : ' by ' + self.creators.collect{|u| u.login}.join(',')}"
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

  alias :to_s :display_name

  private 

  def prepare_content
    # In the case of a cloned collage, we don't need to regenerate these caches. Only regenerate if it's truly new.
    if self.content.blank?
#      logger.warn('CREATED COLLAGE CACHES!')
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

end
