class Import < ApplicationRecord
  belongs_to :bulk_upload
  belongs_to :actual_object, :polymorphic => true
  delegate :name, to: :actual_object, allow_nil: true
  delegate :name_abbreviation, to: :actual_object, allow_nil: true
  delegate :public, to: :actual_object, allow_nil: true
  
  def created_object
    if self.status == "Object Created"
      self.actual_object
    elsif self.status == "Errored"
      nil
    else
      Import.where("dropbox_filepath = ? AND status = 'Object Created'", self.dropbox_filepath).first #.actual_object
    end
  end

  def self.completed_paths(klass)
    Import.where("actual_object_type = ? AND status = 'Object Created'", klass.to_s).map(&:dropbox_filepath).uniq.compact.flatten
  end
end
