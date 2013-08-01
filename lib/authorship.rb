module Authorship
  def author
    owner_list = self.accepted_roles.reject{|r| r.name != 'owner'}
    (owner_list.blank?) ? nil : owner_list.first.users.compact.uniq.first.login.downcase
  end

  def author_display
    owner_list = self.accepted_roles.reject{|r| r.name != 'owner'}
    (owner_list.blank?) ? nil : owner_list.first.users.compact.uniq.first.display
  end

  def author_id
    owner_list = self.accepted_roles.reject{|r| r.name != 'owner'}
    (owner_list.blank?) ? nil : owner_list.first.users.compact.uniq.first.id
  end

  def root_author
    owner_list = self.root.accepted_roles.reject{|r| r.name != 'owner'}
    (owner_list.blank?) ? nil : owner_list.first.users.compact.uniq.first.login.downcase
  end
  
  def root_author_display
    owner_list = self.root.accepted_roles.reject{|r| r.name != 'owner'}
    (owner_list.blank?) ? nil : owner_list.first.users.compact.uniq.first.display
  end
  
  def root_author_id
    owner_list = self.root.accepted_roles.reject{|r| r.name != 'owner'}
    (owner_list.blank?) ? nil : owner_list.first.users.compact.uniq.first.id
  end
end
