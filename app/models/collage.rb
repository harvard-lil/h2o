class Collage < ActiveRecord::Base
  belongs_to :annotatable, :polymorphic => true 


end
