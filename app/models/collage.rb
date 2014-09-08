class Collage < ActiveRecord::Base
  include StandardModelExtensions
  include AncestryExtensions
  include MetadataExtensions
  include CaptchaExtensions
  include VerifiedUserExtensions
  include SpamPreventionExtension
  include FormattingExtensions
  include DeletedItemExtensions
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::TextHelper

  RATINGS_DISPLAY = {
    :remix => "Remixed",
    :bookmark => "Bookmarked",
    :add => "Added to"
  }

  acts_as_taggable_on :tags

  before_destroy :collapse_children
  has_ancestry :orphan_strategy => :restrict

  belongs_to :annotatable, :polymorphic => true
  belongs_to :user
  has_many :annotations, -> { order(:created_at) }, :dependent => :destroy
  has_and_belongs_to_many :user_collections,  :dependent => :destroy
  has_many :defects, :as => :reportable
  has_many :color_mappings
  has_many :playlist_items, :as => :actual_object

  validates_presence_of :annotatable_type, :annotatable_id
  validates_length_of :description, :in => 1..(5.kilobytes), :allow_blank => true
  
  searchable do
    text :display_name, :stored => true, :boost => 3.0
    string :display_name, :stored => true
    string :id, :stored => true
    text :description, :boost => 2.0

    boolean :featured
    boolean :public
    time :created_at
    time :updated_at
    string :tag_list, :stored => true, :multiple => true

    string :user
    string :user_display, :stored => true
    integer :user_id, :stored => true
    string :root_user_display, :stored => true
    integer :root_user_id, :stored => true
    integer :karma
    
    string :klass, :stored => true
    boolean :primary do
      false
    end
    boolean :secondary do
      false
    end
  end

  def h2o_clone(new_user, params)
    collage_copy = self.dup
    collage_copy.name = params[:name]
    collage_copy.public = params[:public]
    collage_copy.description = params[:description]
    collage_copy.created_at = Time.now
    collage_copy.parent = self
    collage_copy.user = new_user
    collage_copy.featured = false
    collage_copy.annotations = []
    collage_copy.color_mappings = []
    collage_copy.tag_list = self.tag_list.join(', ')

    self.annotations.each do |annotation|
      new_annotation = annotation.dup
      new_annotation.cloned = true
      new_annotation.layer_list = annotation.layer_list
      new_annotation.user = new_user
      collage_copy.annotations << new_annotation
    end
    self.color_mappings.each do |color_mapping|
      new_color_mapping = color_mapping.dup
      new_color_mapping.collage_id = collage_copy.id
      collage_copy.color_mappings << new_color_mapping
    end
    collage_copy
  end

  def layer_data
    h = {}
    self.layers.each do |layer|
      map = self.color_mappings.detect { |cm| cm.tag_id == layer.id }
      if map
        h[layer.name] = map.hex
      else
        h[layer.name] = cycle('ffcc00', '99ccff', '99cc33', 'ff9999', 'b2c1d0', 'ff9933', 'cc99cc')
      end
    end
    #hardcoding required layer as dark red
    h["required"] = '6b0000'
    h
  end

  def barcode
    Rails.cache.fetch("collage-barcode-#{self.id}", :compress => H2O_CACHE_COMPRESSION) do
      barcode_elements = self.barcode_bookmarked_added
      self.public_children.each do |child|
        barcode_elements << { :type => "remix",
                              :date => child.created_at,
                              :title => "Remixed to Collage #{child.name}",
                              :link => collage_path(child), 
                              :rating => 5 }
      end

      value = barcode_elements.inject(0) { |sum, item| sum + item[:rating] }
      self.update_attribute(:karma, value)

      barcode_elements.sort_by { |a| a[:date] }
    end
  end

  def display_name
    "#{self.name}, #{self.created_at.to_s(:simpledatetime)}#{(self.user.nil?) ? '' : ' by ' + self.user.login}"
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

  def editable_content
    return '' if self.annotatable.nil?

    doc = Nokogiri::HTML.parse(self.annotatable.content.gsub(/\r\n/, ''))

    # Footnote markup
    doc.css("a").each do |li|
      if li['href'] =~ /^#/
        li['class'] = 'footnote'
      end
    end

    count = 1

    children_nodes = doc.xpath('/html/body').children
    if children_nodes.size == 1 && self.annotatable.content.match('^<div>')
      children_nodes = children_nodes.first.children
    end

    children_nodes.each do |node|
      if node.children.any? && node.text != ''
	      first_child = node.children.first
	      control_node = Nokogiri::XML::Node.new('a', doc)
	      control_node['id'] = "paragraph#{count}"
	      control_node['href'] = "#p#{count}"
	      control_node['class'] = "paragraph-numbering scale0-9"
	      control_node.inner_html = "#{count}"
	      first_child.add_previous_sibling(control_node)
	      count += 1
      end
    end

    CGI.unescapeHTML(doc.xpath("//html/body/*").to_s)
  end

  def current?
    !self.outdated?
  end

  def outdated?
    self.annotatable.version > self.annotatable_version
  end

  def update_annotatable_version_number
    if self.new_record?
      if self.annotatable
        self.annotatable.reload
        if self.annotatable.respond_to?(:version)
          self.annotatable_version = self.annotatable.version
        end
      end
    end
  end

  alias :to_s :display_name

  def xpath_and_offset(doc, tt_pos, anchor)
    results = { :xpath => '', :offset => 0 }
    node = doc.xpath("//tt[@id='#{tt_pos}']").first
    element = node.parent
    while element.name != 'body'
      index = element.xpath("../#{element.name}").index(element) + 1
      results[:xpath] = "/#{element.name}[#{index}]#{results[:xpath]}"
      element = element.parent
    end

    nodes = node.xpath('../*')
    node_index = nodes.index(node)

    if anchor == 'start'
      if node_index != 0
        results[:offset] = nodes[0,node_index].collect { |n| n.text }.join('').length
      end
    else
      results[:offset] = nodes[0,node_index + 1].collect { |n| n.text }.join('').length
    end

    results
  end
  
  def deleteable_tags
    Tag.find_by_sql("SELECT tag_id AS id FROM
      (SELECT tag_id, COUNT(*)
        FROM annotations a
        JOIN taggings t ON a.id = t.taggable_id
        WHERE t.taggable_type = 'Annotation'
        AND a.collage_id = '#{self.id}'
        GROUP BY tag_id) b
      WHERE b.count = 1").collect { |t| t.id }
  end

  def self.color_list
    [
      { :hex => 'ff0080', :text => '#000000' },
      { :hex => '9e00ff', :text => '#FFFFFF' },
      { :hex => '6600ff', :text => '#FFFFFF' },
      { :hex => '2e00ff', :text => '#FFFFFF' },
      { :hex => '000aff', :text => '#FFFFFF' },
      { :hex => '0042ff', :text => '#FFFFFF' },
      { :hex => '007aff', :text => '#FFFFFF' },
      { :hex => '00b3ff', :text => '#000000' },
      { :hex => '00ffdb', :text => '#000000' },
      { :hex => '00ffa3', :text => '#000000' },
      { :hex => '00ff6b', :text => '#000000' },
      { :hex => '05ff00', :text => '#000000' },
      { :hex => '73fd00', :text => '#000000' },
      { :hex => 'abfd00', :text => '#000000' },
      { :hex => 'e4fd00', :text => '#000000' },
      { :hex => 'ffee00', :text => '#000000' },
      { :hex => 'feb62a', :text => '#000000' },
      { :hex => 'fdac12', :text => '#000000' },
      { :hex => 'fe872a', :text => '#000000' },
      { :hex => 'ff3800', :text => '#000000' },
      { :hex => 'fe2a2a', :text => '#000000' }
    ]
  end
  
  def self.get_single_resource(id)
    Collage.where(id: id).includes(:annotations => [:layers, :taggings => :tag]).first
  end
end
