require 'test_helper'

class QuestionInstanceTest < ActiveSupport::TestCase

  should_validate_presence_of :name
  should_ensure_length_in_range :name, 1..250
  should_have_many :questions
  should_have_many :replies, :through => :questions
  should_belong_to :user
  should_belong_to :project
  should_ensure_length_in_range :password, 0..128

  should_validate_numericality_of :featured_question_count,:parent_id
  should_validate_numericality_of :new_question_timeout
  should_validate_numericality_of :old_question_timeout

  should_ensure_length_in_range :description, 0..2000

end
