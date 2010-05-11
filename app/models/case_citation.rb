class CaseCitation < ActiveRecord::Base
  belongs_to :case

  validates_presence_of   :volume, :reporter, :page
  validates_length_of     :volume, :reporter, :page,  :in => 1..200


end
