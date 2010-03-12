module AccessHelper
  include Acl9Helpers

  access_control :show_discussion? do
    allow :admin
    allow :owner
    allow :user
  end

end
