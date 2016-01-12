class Collage < ActiveRecord::Base
  include StandardModelExtensions
  include AncestryExtensions
  include MetadataExtensions
  include CaptchaExtensions
  include VerifiedUserExtensions
  include SpamPreventionExtension
  include DeletedItemExtensions
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::TextHelper

  RATINGS_DISPLAY = {
    :clone => "Cloned",
    :bookmark => "Bookmarked",
    :add => "Added to"
  }

  acts_as_taggable_on :tags

  before_destroy :collapse_children
  has_ancestry :orphan_strategy => :adopt

  belongs_to :annotatable, :polymorphic => true
  belongs_to :user
  has_many :annotations, -> { order(:created_at) }, :dependent => :destroy, :as => :annotated_item
  has_and_belongs_to_many :user_collections,  :dependent => :destroy
  has_many :defects, :as => :reportable
  has_many :color_mappings
  has_many :playlist_items, :as => :actual_object
  has_many :responses, -> { order(:created_at) }, :dependent => :destroy, :as => :resource

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
    string :annotype, :stored => true
    boolean :primary do
      false
    end
    boolean :secondary do
      false
    end
  end

  def annotype
    self.annotatable_type
  end

  # For Rails Admin delete purposes only
  def collages_user_collections
    []
  end

  def h2o_clone(new_user, params)
    collage_copy = self.dup
    collage_copy.name = params[:name] if params.has_key?(:name)
    collage_copy.public = params[:public] if params.has_key?(:public)
    collage_copy.description = params[:description] if params.has_key?(:description)
    collage_copy.created_at = Time.now
    collage_copy.parent = self
    collage_copy.user = new_user
    collage_copy.featured = false
    collage_copy.annotations = []
    collage_copy.color_mappings = []
    collage_copy.tag_list = self.tag_list.join(', ')

    self.annotations.select { |b| !b.error }.each do |annotation|
      new_annotation = annotation.dup
      new_annotation.cloned = true
      new_annotation.layer_list = annotation.layer_list
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
      elsif layer.name == "required"
        h[layer.name] = "6b0000"
      else
        h[layer.name] = cycle('ffcc00', '99ccff', '99cc33', 'ff9999', 'b2c1d0', 'ff9933', 'cc99cc')
      end
    end
    h
  end

  def barcode
    Rails.cache.fetch("collage-barcode-#{self.id}", :compress => H2O_CACHE_COMPRESSION) do
      barcode_elements = self.barcode_bookmarked_added
      self.public_children.each do |child|
        barcode_elements << { :type => "clone",
                              :date => child.created_at,
                              :title => "Cloned to #{child.name}",
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
  alias :to_s :display_name

  def highlights_only
    self.annotations.map(&:highlight_only).flatten.uniq.compact 
  end

  def layers
    self.annotations.map(&:layers).flatten.uniq
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
    layers
  end

  def annotations_as_export_json
    attrs = %i[
      id
      collage_id
      annotated_item_id
      annotated_item_type
      annotation
      xpath_start
      xpath_end
      start_offset
      end_offset
      link
      hidden
      highlight_only
    ]

    # TODO: Fix N+1 error with this. UNTESTED
    # self.annotations.includes([:layers, :taggings => :tag]).inject({}) {|h, a|
    # Tweak xpath selectors to work with similarly tweaked DOM present during export
    new_h2 = "/div[contains(concat(' ', @class, ' '), ' new-h2 ')]"
    self.annotations.inject({}) {|h, a|
      a.xpath_start.sub!(/\/h2/, new_h2)
      a.xpath_end.sub!(  /\/h2/, new_h2)
      h["a#{a.id}"] = a.to_json(only: attrs, include: [:layers])
      h
    }.to_json
  end

  def printable_content
    self.editable_content(true)
  end

  def editable_content(convert_h_tags=false)
    return '' if self.annotatable.nil?

    original_content = ''
    if self.version == self.annotatable.version
      original_content = self.annotatable.content
    else
      original_content = self.annotatable.frozen_items.detect { |f| f.version = self.version }.content
    end

    doc = Nokogiri::HTML.parse(original_content.gsub(/\r\n/, ''))

    doc.xpath('//a[starts-with(@href, "#")]').each do |li|
      li['class'] = 'footnote'
    end

    children_nodes = doc.xpath('/html/body').children
    if children_nodes.size == 1 && self.annotatable.content.match('^<div>')
      children_nodes = children_nodes.first.children
    end

    count = 1
    children_nodes.each do |node|
      if node.children.any? && node.text != ''
        #first_child = node.children.first
        control_node = Nokogiri::XML::Node.new('a', doc)
        control_node['id'] = "paragraph#{count}"
        control_node['href'] = "#p#{count}"
        control_node['class'] = "paragraph-numbering scale0-9"
        control_node.inner_html = "#{count}"
        #TODO: Verify the change from first_child.add... to node.add... do not break anything outside of the print export
        #first_child.add_previous_sibling(control_node)
        node.add_previous_sibling(control_node)
        count += 1
      end
    end

    #This is kind of a hack to avoid re-parsing everything in printable_content()
    if convert_h_tags
      PlaylistExporter.convert_h_tags(doc)
      PlaylistExporter.inject_doc_styles(doc)
    end
    html = doc.xpath("/html/body/*").to_s

    convert_h_tags ? html : CGI.unescapeHTML(html)
  end

  def deleteable_tags
    Tag.find_by_sql("SELECT tag_id AS id FROM
      (SELECT tag_id, COUNT(*)
        FROM annotations a
        JOIN taggings t ON a.id = t.taggable_id
        WHERE t.taggable_type = 'Annotation'
        AND a.annotated_item_id = '#{self.id}'
        AND a.annotated_item_type = 'Collage'
        GROUP BY tag_id) b
      WHERE b.count = 1").collect { |t| t.id }
  end

  def self.color_list
    [
      { :hex => 'ff0080', :text => '#000000' },
      { :hex => '9e00ff', :text => '#FFFFFF' },
      { :hex => '6600ff', :text => '#FFFFFF' },
      { :hex => '2e00ff', :text => '#FFFFFF' },
      { :hex => '00ffdb', :text => '#000000' },
      { :hex => '05ff00', :text => '#000000' },
      { :hex => 'ffee00', :text => '#000000' },
      { :hex => 'fe872a', :text => '#000000' },
      { :hex => 'ff3800', :text => '#000000' }
    ]
  end
  
  def self.get_single_resource(id)
    Collage.where(id: id).includes(:annotations => [:layers, :taggings => :tag]).first
  end

  def annotated_label
    self.annotatable_type == "Case" ? "Annotated Case" : "Annotated Text"
  end
end
