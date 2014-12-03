class Metadatum < ActiveRecord::Base
  belongs_to :classifiable, :polymorphic => true

  DISPLAY_FIELDS = [:contributor, :coverage, :creator, :date, :description, :format, :identifier, :publisher, :relation, :rights, :subject, :source, :title]

  # From http://dublincore.org/documents/dcmi-type-vocabulary/
  DCMI_TYPE = {
    'Collection' => 'Collection',
    'Dataset' => 'Dataset',
    'Event' => 'Event',
    'Image' => 'Image',
    'InteractiveResource' => 'Interactive Resource',
    'MovingImage' => 'Video',
    'PhysicalObject' => 'Physical Object',
    'Service' => 'Service',
    'Software' => 'Software',
    'Sound' => 'Sound',
    'Text' => 'Text'
  }

  def self.dcmi_type_select_options
    DCMI_TYPE.keys.collect{|t| [DCMI_TYPE[t],t]}
  end

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
