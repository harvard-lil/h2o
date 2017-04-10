# == Schema Information
#
# Table name: case_requests
#
#  id                   :integer          not null, primary key
#  full_name            :string(500)      not null
#  decision_date        :date             not null
#  author               :string(150)      not null
#  case_jurisdiction_id :integer
#  docket_number        :string(150)      not null
#  volume               :string(150)      not null
#  reporter             :string(150)      not null
#  page                 :string(150)      not null
#  bluebook_citation    :string(150)      not null
#  status               :string(150)      default("new"), not null
#  created_at           :datetime
#  updated_at           :datetime
#  user_id              :integer          default(0), not null
#

class CaseRequest < ApplicationRecord
  validates_presence_of :full_name, :author, :bluebook_citation,
                        :docket_number, :volume, :reporter, :page,
                        :reporter, :page, :status, :decision_date
  validates_length_of   :full_name,            :in => 1..500
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
    self.full_name
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
