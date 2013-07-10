class CaseCitation < ActiveRecord::Base
  belongs_to :case

  validates_presence_of   :volume, :reporter, :page
  validates_length_of     :volume, :reporter, :page,  :in => 1..200

  def display_name
    "#{self.volume} #{self.reporter.gsub(/\./, '')} #{self.page}"
  end

  alias :to_s :display_name

end
