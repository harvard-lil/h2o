module AuthUtilities
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
    owner_list = self.accepted_roles.reject{|r| r.name != 'owner'}
    (owner_list.blank?) ? [] : owner_list.first.users.compact.uniq
  end

  def creators
    creator_list = self.accepted_roles.reject{|r| r.name != 'creator'}
    (creator_list.blank?) ? [] : creator_list.first.users.compact.uniq
  end

  def editors
    editor_list = self.accepted_roles.reject{|r| r.name != 'editor'}
    (editor_list.blank?) ? [] : editor_list.first.users.compact.uniq
  end


end
