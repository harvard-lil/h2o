# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#   
#   cities = City.create([{ :name => 'Chicago' }, { :name => 'Copenhagen' }])
#   Major.create(:name => 'Daley', :city => cities.first)

qi = QuestionInstance.create({:name => 'Test Question Instance', :description => 'This is a test question instance. Fun!', :user_id => 1, :project_id => 1, :password => nil, :featured_question_count => 4, :old_question_timeout => 1800, :new_question_timeout => 300})
qi2 = QuestionInstance.create({:name => 'Another Test Question Instance', :user_id => 1, :project_id => 1, :password => nil, :featured_question_count => 4, :old_question_timeout => 1800, :new_question_timeout => 300})

q = Question.create(:question => "Why is the sky #0000ff?", :user_id => 1, :question_instance => qi, :posted_anonymously => true)
q = Question.create(:question => "Why is the grass #00ff00?", :user_id => 1, :question_instance => qi, :posted_anonymously => true)



