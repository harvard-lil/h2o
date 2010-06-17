class Collage < ActiveRecord::Base
  acts_as_voteable

  acts_as_category :scope => 'annotatable_id, annotatable_type'

  belongs_to :annotatable, :polymorphic => true
  belongs_to :user
  has_many :annotations, :order => 'created_at'
  before_create :prepare_content

  validates_presence_of :name
  validates_length_of :name, :in => 1..250
  validates_length_of :description, :in => 1..(5.kilobytes), :allow_blank => true

  def layers
    self.annotations.find(:all, :include => [:layers]).collect{|a| a.layers}.flatten.uniq
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
          item['class'] = "#{item['class']} #{layer_list.join(' ')}"
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
    class_name = 1
    doc.css('p,div,li,td,th,h1,h2,h3,h4,h5,h6,address,blockquote,dl,ol,ul,pre,dd,dt').each do |item|
      if item.is_a?(Nokogiri::XML::Element) 
        item['id'] = "n#{class_name}" 
        class_name += 1
        if ! item.children.blank?
          text_content = item.inner_html.split.map{|word|class_name += 1; "<tt id='t#{class_name}'>" + word + '</tt>'}.join(' ')
          item.inner_html = text_content
        end
      end
    end
    self.content = doc.xpath("//html/body/*").to_s
  end
end
