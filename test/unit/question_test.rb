require 'test_helper'

class QuestionTest < ActiveSupport::TestCase
  should_not_allow_values_for :email, 'foobar','bee','@ff.com'
  should_allow_values_for :email, 'foo@bar.com','foo+bar@com.com', 'foo.bar@com.com', 'foo@bar.person'
end
