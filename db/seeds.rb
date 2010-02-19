# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:

['one','two','three','four','five','six','seven','eight'].each do |i|
  qi = QuestionInstance.create({:name => 'Test Question Instance ' + i, :description => 'This is a test question instance, number ' + i, :user_id => 1, :project_id => 1, :password => nil, :featured_question_count => 4, :old_question_timeout => 1800, :new_question_timeout => 300})
  q = Question.create(:question => "Why is the sky #0000ff?", :user_id => 1, :question_instance => qi, :posted_anonymously => true)
  q = Question.create(:question => "Why is the grass #00ff00?", :user_id => 1, :question_instance => qi, :posted_anonymously => true)
  q = Question.create(:question => "Why are cooked lobsters #ff0000?", :user_id => 1, :question_instance => qi, :posted_anonymously => true)
  q = Question.create(:question => "How much wood could a woodchuck chuck if a woodchuck could chuck wood?", :user_id => 1, :question_instance => qi, :posted_anonymously => true)
end
