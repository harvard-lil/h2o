class UserCollection < ActiveRecord::Base
  belongs_to :user
  has_and_belongs_to_many :users
  has_and_belongs_to_many :playlists
  has_and_belongs_to_many :collages
  has_many :permission_assignments, :dependent => :destroy

  validates_presence_of :user_id, :name

  accepts_nested_attributes_for :permission_assignments, :allow_destroy => true
  accepts_nested_attributes_for :users, :allow_destroy => true
  accepts_nested_attributes_for :playlists, :allow_destroy => true
  accepts_nested_attributes_for :collages, :allow_destroy => true

  searchable do
    text :name
    time :created_at
    time :updated_at

    integer :user_id, :stored => true
    boolean :public do
      true
    end
    string :klass, :stored => true do
      'UserCollection'
    end
    boolean :primary do
      false
    end
    boolean :secondary do
      false
    end
  end

  def klass_partial
    "usercollection"
  end
  def klass_sym
    :usercollection
  end
end
