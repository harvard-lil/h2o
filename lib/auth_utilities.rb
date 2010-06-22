module AuthUtilities

  ### Pulls current user from authlogic
  def current_user
    session = UserSession.find
    current_user = session && session.user
    return current_user
  end

  def admin?
    return self.accepts_role?(:admin, current_user)
  end

  def owner?
    return self.accepts_role?(:owner, current_user)
  end
  
  def editor?
    return self.accepts_role?(:editor, current_user)
  end
  
  def user?
    return self.accepts_role?(:user, current_user)
  end

  def owners
    owner_list = self.accepted_roles.find_by_name('owner')
    (owner_list.blank?) ? nil : owner_list.users.compact.uniq
  end

  def creators
    creator_list = self.accepted_roles.find_by_name('creator')
    (creator_list.blank?) ? nil : creator_list.users.compact.uniq
  end

end
