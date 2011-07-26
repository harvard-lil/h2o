require 'tagging_extensions'
require 'redcloth_extensions'
require 'playlistable_extensions'
require 'ancestry_extensions'

class Collage < ActiveRecord::Base
  include H2oModelExtensions
  extend RedclothExtensions::ClassMethods
  extend AncestryExtensions::ClassMethods
  include PlaylistableExtensions
  include AncestryExtensions::InstanceMethods
  include TaggingExtensions::InstanceMethods
  include AuthUtilities
  include MetadataExtensions

  acts_as_taggable_on :tags
  acts_as_authorization_object

  def self.tag_list
    Tag.find_by_sql("SELECT ts.tag_id AS id, t.name FROM taggings ts
      JOIN tags t ON ts.tag_id = t.id
      WHERE taggable_type = 'Collage'
      GROUP BY ts.tag_id, t.name
      ORDER BY COUNT(*) DESC LIMIT 25")
  end

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

  before_destroy :collapse_children
  has_ancestry :orphan_strategy => :restrict 

  belongs_to :annotatable, :polymorphic => true
  has_many :annotations, :order => 'created_at', :dependent => :destroy

  # Create the content we're going to annotate. This is a might bit inefficient, mainly because
  # we're doing a heavy bit of parsing on each attempted save. It is probably better than allowing
  # the creation of a contentless collage, though.
  before_validation_on_create :prepare_content

  validates_presence_of :annotatable_type, :annotatable_id
  validates_length_of :description, :in => 1..(5.kilobytes), :allow_blank => true

  # TODO: Figure out why tags & annotations breaks in searchable
  searchable(:include => [:tags]) do #, :annotations => {:layers => true}]) do
    text :display_name, :stored => true, :boost => 3.0
    string :display_name, :stored => true
    string :id, :stored => true
    text :description, :boost => 2.0
    text :indexable_content
    boolean :active
    boolean :public
    time :created_at
    string :tag_list, :stored => true, :multiple => true
    string :author

    string :annotatable #, :stored => true
    string :annotations, :multiple => true
    string :layer_list, :multiple => true
  end

  def author
    owner = self.accepted_roles.find_by_name('owner')
    owner.nil? ? nil : owner.user.login.downcase
  end

  def fork_it(new_user)
    collage_copy = self.clone
    collage_copy.name = "#{self.name} copy"
    collage_copy.created_at = Time.now
    collage_copy.parent = self
    collage_copy.accepts_role!(:owner, new_user)
    collage_copy.accepts_role!(:creator, new_user)
    self.creators.each do|c|
      collage_copy.accepts_role!(:original_creator,c)
    end
    self.annotations.each do |annotation|
      new_annotation = annotation.clone
      new_annotation.collage = collage_copy
      #copy tags
      new_annotation.layer_list = annotation.layer_list
      new_annotation.accepts_role!(:creator, new_user)
      new_annotation.accepts_role!(:owner, new_user)
      new_annotation.parent = annotation
      annotation.creators.each do|c|
        new_annotation.accepts_role!(:original_creator, c)
      end
      new_annotation.save
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

  def layer_list
    self.layers.map(&:name)
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
    doc = Nokogiri::HTML.parse(self.content)
    annotation_rules = []

    #Note: This is for optimization
    annotations = Annotation.find_all_by_collage_id(self.id, :include => :layers)

    annotations.each do|ann|
      annotation_rules << {
        :start => ann.annotation_start_numeral.to_i, 
        :end => ann.annotation_end_numeral.to_i, 
        :id => ann.id.to_s,
        :layer_list => ann.layers.collect{|l| "l#{l.id}"},
        :layer_names => ann.layers.collect{ |l| l.name }.join(', '),
        :content => ann.formatted_annotation_content
      }
    end

    unlayered_start = 1
    unlayered_start_node = true
    unlayered_ids = []

    doc.xpath('//tt').each do |node|
      node_id_num = node['id'][1,node['id'].length - 1].to_i
      classes = []
      annotation_rules.each do |r|
        if node_id_num == r[:start]
          span_node = Nokogiri::XML::Node.new('a', doc)
          sclasses = ["control-divider", "annotation-control-#{r[:id]}"]
          r[:layer_list].each { |l| sclasses.push("annotation-control-#{l}") }
          span_node['class'] = sclasses.join(' ')
          span_node['data-id'] = "#{r[:id]}"
          span_node['href'] = '#'
          node.add_previous_sibling(span_node)
        end
        if node_id_num == r[:end]
          # If node at end of annotation, adding divider, asterisk, ellipsis and annotation
          span_node = Nokogiri::XML::Node.new('a', doc)
          sclasses = ["arr", "control-divider", "annotation-control-#{r[:id]}"]
          r[:layer_list].each { |l| sclasses.push("annotation-control-#{l}") }
          span_node['class'] = sclasses.join(' ')
          span_node['href'] = '#'
          span_node['data-id'] = "#{r[:id]}"
          node.add_next_sibling(span_node)

          ellipsis_node = Nokogiri::XML::Node.new('a', doc)
          ellipsis_classes = [].push('annotation-ellipsis')
          r[:layer_list].each { |l| ellipsis_classes.push("annotation-ellipsis-#{l}") }
          ellipsis_node['class'] = ellipsis_classes.flatten.join(' ')
          ellipsis_node['id'] = "annotation-ellipsis-#{r[:id]}"
          ellipsis_node['data-id'] = "#{r[:id]}"
          ellipsis_node.inner_html = '[...]'

          if r[:content] != ''
            link_node = Nokogiri::XML::Node.new('a', doc)
            link_classes = [].push('annotation-asterisk').push(r[:layer_list]).flatten
            link_node['class'] = link_classes.join(' ')
            link_node['title'] = r[:layer_names] 
            link_node['id'] = "annotation-asterisk-#{r[:id]}"
            link_node['data-id'] = "#{r[:id]}"
            ann_node = Nokogiri::XML::Node.new('span', doc)
            ann_node['class'] = 'annotation-content'
            ann_node['id'] = "annotation-content-#{r[:id]}"
            ann_node.inner_html = r[:content]
            span_node.add_next_sibling(ellipsis_node)
            ellipsis_node.add_next_sibling(ann_node)
            ann_node.add_next_sibling(link_node)
          else 
            node.add_next_sibling(ellipsis_node)
          end
        end

        if node_id_num >= r[:start] and node_id_num <= r[:end]
          classes = classes.push('a' + r[:id]).push(r[:layer_list]).flatten
        end
      end

      if classes.length > 0
        unlayered_start = node_id_num + 1
        unlayered_start_node = true
        classes.push('a')
        node['class'] = classes.uniq.join(' ')
      else
        node['class'] = "unlayered unlayered_#{unlayered_start}"
        if unlayered_start_node
          unlayered_ids.push(unlayered_start)
          control_node = Nokogiri::XML::Node.new('a', doc)
          control_node['class'] = "unlayered-control unlayered-control-start unlayered-control-#{unlayered_start}"
          control_node['data-id'] = "#{unlayered_start}"
          control_node['href'] = '#'
          node.add_previous_sibling(control_node)
          link_node = Nokogiri::XML::Node.new('a', doc)
          link_node['class'] = 'unlayered-ellipsis'
          link_node['id'] = "unlayered-ellipsis-#{unlayered_start}"
          link_node['data-id'] = "#{unlayered_start}"
          link_node['href'] = '#'
          link_node.inner_html = '[...]'
          node.add_previous_sibling(link_node)
          node['class'] = "#{node['class']} unlayered_start"
          unlayered_start_node = false
        end
      end
    end

    unlayered_ids.each do |id|
      node = doc.css("tt.unlayered_#{id}").last
      control_node = Nokogiri::XML::Node.new('a', doc)
      control_node['class'] = "unlayered-control unlayered-control-end unlayered-control-#{id}"
      control_node['data-id'] = "#{id}"
      control_node['href'] = '#'
      node.add_next_sibling(control_node)
    end

    count = 1
    doc.xpath('//p | //center').each do |node|
      tt_size = node.css('tt').size  #xpath tt isn't working because it's not selecting all children (possible TODO later)
      if node.children.size > 0 && tt_size > 0
        unlayered_start_size = node.css('tt.unlayered_start').size
        unlayered_size = node.css("tt.unlayered").size
        if unlayered_start_size == 0 && (tt_size == unlayered_size)
          node.css('tt').first['class'] ||= ''
          node['class'] = node.css('tt').first['class']
        end

        first_child = node.children.first
        control_node = Nokogiri::XML::Node.new('span', doc)
        control_node['class'] = "paragraph-numbering"
        control_node.inner_html = "#{count}"
        first_child.add_previous_sibling(control_node)
        count += 1
      end
    end

    doc.xpath("//html/body/*").to_s
  end

  alias :to_s :display_name

  def bookmark_name
    self.name
  end

  private 

  def prepare_content
    if self.content.blank?
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
