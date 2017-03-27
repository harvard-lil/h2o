# == Schema Information
#
# Table name: metadata
#
#  id                :integer          not null, primary key
#  contributor       :string(255)
#  coverage          :string(255)
#  creator           :string(255)
#  date              :date
#  description       :string(5242880)
#  format            :string(255)
#  identifier        :string(255)
#  language          :string(255)      default("en")
#  publisher         :string(255)
#  relation          :string(255)
#  rights            :string(255)
#  source            :string(255)
#  subject           :string(255)
#  title             :string(255)
#  dc_type           :string(255)      default("Text")
#  classifiable_type :string(255)
#  classifiable_id   :integer
#  created_at        :datetime
#  updated_at        :datetime
#

class Metadatum < ApplicationRecord
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
