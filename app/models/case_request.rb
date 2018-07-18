class CaseRequest < ApplicationRecord
  validates_presence_of :name, :author, :bluebook_citation,
                        :docket_number, :volume, :reporter, :page,
                        :reporter, :page, :status, :decision_date
  validates_length_of   :name,                 :in => 1..500
  validates_length_of   :author,               :in => 1..150
  validates_length_of   :bluebook_citation,    :in => 1..150
  validates_length_of   :docket_number,        :in => 1..150
  validates_length_of   :volume,               :in => 1..150
  validates_length_of   :reporter,             :in => 1..150
  validates_length_of   :page,                 :in => 1..150

  has_one :case
  belongs_to :case_jurisdiction
  belongs_to :user

  default_scope { where("status != 'approved'") }

  def display_name
    self.name
  end

  def klass_partial
    'case_request'
  end
  def klass_sym
    :case_request
  end

  alias :to_s :display_name
  alias :name :display_name

  def approve!
    self.update_attribute('status', 'approved')
  end

  def public?
    true
  end
end
