class Collage < ActiveRecord::Base
  acts_as_voteable

  acts_as_category :scope => 'annotatable_id, annotatable_type'

  belongs_to :annotatable, :polymorphic => true
  belongs_to :user
  has_many :annotations, :order => 'created_at'

  validates_presence_of :name
  validates_length_of :name, :in => 1..250
  validates_length_of :description, :in => 1..(5.kilobytes), :allow_blank => true

  def layers
    self.annotations.find(:all, :include => [:layers]).collect{|a| a.layers}.flatten.uniq
  end

  def annotatable_content
    if ! self.layers.blank?
      doc = Nokogiri::HTML.parse(self.annotatable.content)
      self.annotations.each do |ann|

        layer_list = ann.layers.collect{|l| "l#{l.id}"}
        layer_list << "a#{ann.id}"
        RAILS_DEFAULT_LOGGER.debug("layer list: #{layer_list}")

        startId = ann.annotation_start[1,ann.annotation_start.length - 1]
        endId = ann.annotation_end[1,ann.annotation_end.length - 1]

        doc.xpath("//tt[starts-with(@id,'t') and substring-after(@id,'t')>='" + startId + "' and substring-after(@id,'t')<='" + endId + "']").each do |item|
          item['class'] = "#{item['class']} #{layer_list.join(' ')}"
        end
      end
      doc.xpath("//html/body/*").to_s
    else
      self.annotatable.content
    end

  end

end
