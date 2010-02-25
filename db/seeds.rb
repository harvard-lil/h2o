# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:

iterations = ['one','two','three','four','five','six','seven','eight','nine','ten','eleven','twelve']

iterations.each do |i|
  qi = QuestionInstance.create({:name => 'Test Question Instance ' + i, :description => 'This is a test question instance, number ' + i, :user_id => 1, :project_id => 1, :password => nil, :featured_question_count => 4, :old_question_timeout => 1800, :new_question_timeout => 300})

  Question.create(
    [{:question => "Why is the sky #0000ff?", :user_id => 1, :question_instance => qi, :posted_anonymously => true, :sticky => true}],
    [{:question => "Why is the grass #00ff00?", :user_id => 1, :question_instance => qi, :posted_anonymously => true}],
    [{:question => "Why are cooked lobsters #ff0000?", :user_id => 1, :question_instance => qi, :posted_anonymously => true}],
    [{:question => "How much wood could a woodchuck chuck if a woodchuck could chuck wood?", :user_id => 1, :question_instance => qi, :posted_anonymously => true}]
  ) do |q|

  end

  iterations.each do |q|
    Question.create(:question => "Question number #{q}", :user_id => 1, :question_instance => qi, :posted_anonymously => true)
  end

end
