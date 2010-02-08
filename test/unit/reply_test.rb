require 'test_helper'

class ReplyTest < ActiveSupport::TestCase
  context "A Reply" do
    should_belong_to :question
    should_belong_to :user
    should_validate_presence_of  :question_id
    should_validate_presence_of  :reply
    should_ensure_length_in_range :reply, 0..1000
    should_ensure_length_in_range :email, 0..250
    should_not_allow_values_for :email, 'foobar','bee','@ff.com'
    should_allow_values_for :email, 'foo@bar.com','foo+bar@com.com', 'foo.bar@com.com', 'foo@bar.person'
    [:parent_id, :children_count, :ancestors_count, :descendants_count].each do |col|
      should_validate_numericality_of col
    end
  end
end
