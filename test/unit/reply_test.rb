require 'test_helper'

class ReplyTest < ActiveSupport::TestCase
  should_belong_to :question
  should_belong_to :user
  should_validate_presence_of  :question_id
  should_validate_presence_of  :reply
  should_ensure_length_in_range :reply, 0..1000
  should_ensure_length_in_range :email, 0..250
end
