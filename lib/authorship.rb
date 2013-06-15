module Authorship
  def author
    owner_list = self.accepted_roles.reject{|r| r.name != 'owner'}
    (owner_list.blank?) ? nil : owner_list.first.users.compact.uniq.first.login.downcase
  end
end
