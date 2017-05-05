# == Schema Information
#
# Table name: casebooks
#
#  id            :integer          not null, primary key
#  title         :string
#  slug          :string
#  subtitle      :string
#  headnote      :text
#  public        :boolean          default(TRUE), not null
#  book_id       :integer
#  ordinals      :integer          default([]), not null, is an Array
#  copy_of_id    :integer
#  is_alias      :boolean
#  resource_type :string
#  resource_id   :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

class Casebook::Book < Casebook::Generic
  default_scope {where(book_id: nil)}

  validates :book_id, presence: false
  validates_length_of :ordinals, is: 0

  has_many :contents, -> {order :ordinals}, class_name: 'Casebook::Contents', inverse_of: :book, foreign_key: :book_id

  has_many :collaborators, class_name: 'Casebook::Collaborator', dependent: :destroy, inverse_of: :casebook, foreign_key: :casebook_id
  include Casebook::Concerns::Collaborators
  include Casebook::Concerns::Contents

  def owner
    owners.first
  end

  def owner= user
    collaborators << Casebook::Collaborator.new(user: user, role: 'owner')
  end

  def title
    super || I18n.t('casebooks.untitled-book', id: id)
  end

  def to_param
    "#{id}-#{slug}"
  end
end
