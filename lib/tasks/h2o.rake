namespace :h2o do

  desc 'Test case import'
  task(:import_cases => :environment) do
    c = Case.new(:short_name => 'Short Name', :full_name => 'Full Name')
    c.content = File.open(RAILS_ROOT + '/doc/design/sample_case.html').read
    c.save!
    u = User.find :first
    cl = Collage.new(:user => u, :annotatable => c, :name => 'My test collage')
    cl.save
  end

end
