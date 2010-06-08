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

end
