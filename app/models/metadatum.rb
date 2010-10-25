class Metadatum < ActiveRecord::Base
  include H2oModelExtensions
  include AuthUtilities
  belongs_to :classifiable, :polymorphic => true

  private
  
  validate do |rec|
    columns = rec.class.columns.collect{|c|c.name}
    valid = false
    columns.each do|c|
      unless rec.send(c.to_sym).blank?
       valid = true
      end
    end
    unless valid
      rec.errors.add_to_base('You must define at least one metadata attribute.')
    end
  end

end