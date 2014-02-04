class CollageLink < ActiveRecord::Base
  belongs_to :host_collage, :class_name => "Collage", :foreign_key => "host_collage_id"
  belongs_to :linked_collage, :class_name => "Collage", :foreign_key => "linked_collage_id"
  validates_presence_of :link_text_start, :link_text_end, :host_collage_id, :linked_collage_id

  def start_number
    self.link_text_start.scan(/\d+/).first.to_i
  end

  def end_number
    self.link_text_end.scan(/\d+/).first.to_i
  end
end
