class Case < ActiveRecord::Base
  has_many :case_citations
  has_many :case_docket_numbers
  belongs_to :case_jurisdiction
  has_many :annotations
  has_many :collages, :as => :annotatable, :dependent => :destroy

  validates_presence_of   :short_name, :full_name, :content
  validates_length_of     :short_name,      :in => 1..150
  validates_length_of     :full_name,       :in => 1..500
  validates_length_of     :party_header,    :in => 1..(10.kilobytes), :allow_blank => true
  validates_length_of     :lawyer_header,   :in => 1..(2.kilobytes), :allow_blank => true
  validates_length_of     :header_html,     :in => 1..(15.kilobytes), :allow_blank => true
  validates_length_of     :content,         :in => 1..(500.kilobytes), :allow_blank => true

end
