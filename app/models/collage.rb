# == Schema Information
#
# Table name: collages
#
#  id                 :integer          not null, primary key
#  annotatable_type   :string(255)
#  annotatable_id     :integer
#  name               :string(250)      not null
#  description        :string(5120)
#  created_at         :datetime
#  updated_at         :datetime
#  word_count         :integer
#  ancestry           :string(255)
#  public             :boolean          default(TRUE)
#  readable_state     :string(5242880)
#  words_shown        :integer
#  karma              :integer
#  pushed_from_id     :integer
#  user_id            :integer          default(0), not null
#  annotator_version  :integer          default(2), not null
#  featured           :boolean          default(FALSE), not null
#  created_via_import :boolean          default(FALSE), not null
#  version            :integer          default(1), not null
#  enable_feedback    :boolean          default(TRUE), not null
#  enable_discussions :boolean          default(FALSE), not null
#  enable_responses   :boolean          default(FALSE), not null
#

class Collage < ApplicationRecord
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

  def annotations_for_export
    # Tweak xpath selectors to work with similarly tweaked DOM present during export
    # NOTE: This needs to be tweaked to work correctly with xpath selectors that
    # contain h2 tags *and* don't start with the same node selector thingy. E.g.
    # xpath_start: "/center[3]/p[1]", xpath_end: "/h2[1]"  #not supported

    # TODO: Change any xpath with that contains the string "div" to add something
    #   to the selector that excludes class contains noxpath (don't bother
    #   normalizing spaces b/c we add this ourself.) This is how we will work
    #   around the fact that changing H? tags to divs elsewhere has now broken

    eager_loaded_annotations.inject({}) {|h, a|
      remap_xpath(a.xpath_start)
      remap_xpath(a.xpath_end)
      h["a#{a.id}"] = a.to_json(include: [:layers])
      h
    }
  end

  def remap_xpath(xpath)
    # Annotations with H tags in their xpath_start or xpath_end need to be mapped
    #   to their corresponding DIV tag because that is what the view does.
    #   Annotations with DIV tags in their xpath_start or xpath_end need to be
    #   mapped to exclude class 'nxp' for the same reasons.

    # TODO: I think there are still issues with P tags missing their annotations due to
    #   how aggressively we clean up junk lib/standard_model_extensions.rb. That might
    #   not actually be relevant based on where that junk is getting cleared. If it's
    #   not getting removed from inside the main text of the annotated item, then it
    #   probably can't be breaking anything. This is a good type of lead, though.
    if (match = xpath.to_s.match(%r|(/div)(.+)|))
      prefix = match[1]
      suffix = match[2]
      xpath.sub!(match[0], "#{prefix}[not(contains(concat(' ', @class, ' '), ' nxp '))]#{suffix}")
    elsif (match = xpath.to_s.match(%r|/(h\d+)|))
      h_tag = match[1]
      xpath.sub!(match[0], "/div[contains(concat(' ', @class, ' '), ' new-#{h_tag} ')]" )
    end
  end

  def annotations_for_show
    # TODO: consolidate this with annotations_for_export with an on/off switch
    #   for the xpath translation.
    eager_loaded_annotations.inject({}) {|h, a|
      h["a#{a.id}"] = a.to_json(include: :layers, methods: :user_attribution)
      h
    }
  end

  def printable_content
    editable_content(true)
  end

  def editable_content(convert_h_tags=false)
    return '' if self.annotatable.nil?

    original_content = ''
    if self.version == self.annotatable.version
      original_content = self.annotatable.content
    else
      # BUG: Is that supposed to be an assignment or a comparison?
      original_content = self.annotatable.frozen_items.detect { |f| f.version = self.version }.content
    end

    doc = Nokogiri::HTML.parse(original_content.gsub(/\r\n/, ''))

    add_footnote_class(doc)

    children_nodes = doc.xpath('/html/body').children
    if children_nodes.size == 1 && self.annotatable.content.match('^<div>')
      children_nodes = children_nodes.first.children
    end

    add_paragraph_numbers(doc, children_nodes)

    #This is kind of a hack to avoid re-parsing everything in printable_content()
    if convert_h_tags
      PlaylistExportJob.new.convert_h_tags(doc)
      PlaylistExportJob.new.inject_doc_styles(doc)
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

  private

  def add_footnote_class(doc)
    doc.xpath('//a[starts-with(@href, "#")]').each do |li|
      li['class'] = 'footnote'
    end
  end

  def add_paragraph_numbers(doc, children_nodes)
    children_nodes.each_with_index do |node, count|
      next unless node.children.any? && node.text != ''

      count1 = count + 1
      control_node = Nokogiri::XML::Node.new('a', doc)
      control_node['id'] = "paragraph#{count1}"
      control_node['href'] = "#p#{count1}"
      control_node['class'] = "paragraph-numbering scale0-9"
      control_node.inner_html = count1.to_s

      #new school, which breaks the old weinberger anno in collage 35961
      node.add_previous_sibling(control_node)

      #old school, but this probably breaks TOC links or TOC text in mac or something, which is why we would have changed it in the first place.
      # this works in show and export view
      #node.children.first.add_previous_sibling(control_node)
    end
  end

  def eager_loaded_annotations
    annotations.includes([:layers, :taggings => :tag])
  end

end
