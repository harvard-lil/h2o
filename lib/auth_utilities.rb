module AuthUtilities
  def current_user
    session = UserSession.find
    current_user = session && session.user
    return current_user
  end

  def superadmin?
    return current_user && current_user.has_role?(:superadmin)
  end

  def owner?
    return self.user == current_user
  end

  def editor?
    return self.accepts_role?(:editor, current_user)
  end

  def user?
    return self.accepts_role?(:user, current_user)
  end

  def editors
    editor_list = self.accepted_roles.reject{|r| r.name != 'editor'}
    (editor_list.blank?) ? [] : editor_list.first.users.compact.uniq
  end
end
