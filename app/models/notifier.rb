class Notifier < ActionMailer::Base
  include AuthUtilities
  
  helper :application

  @controller = RotisserieDiscussion

  def notify(rotisserie_post)
    from_user = rotisserie_post.user

    if rotisserie_post.parent_id.nil?
      to_user = rotisserie_post.rotisserie_discussion.user
      msg_text = "the discussion #{link_to rotisserie_post.rotisserie_discussion.output, rotisserie_discussion_url(rotisserie_post.rotisserie_discussion_id)}"
    else
      parent_post = RotisseriePost.find(rotisserie_post.parent_id)
      to_user = parent_post.user
      msg_text = "a post in the discussion #{link_to rotisserie_post.rotisserie_discussion.output, rotisserie_discussion_url(rotisserie_post.rotisserie_discussion_id)}"
    end

    type_description = "notify"

      discussion_tracker_hash = {
        :rotisserie_discussion_id => rotisserie_post.rotisserie_discussion_id,
        :rotisserie_post_id => rotisserie_post.id,
        :user_id => to_user.id,
        :notify_description => type_description
      }

      if !NotificationTracker.exists?(discussion_tracker_hash)
        NotificationTracker.create(discussion_tracker_hash)
      end

    recipients   to_user.email_address
    subject      "Rotisserie Reply Notification"
    from         "noreply@berkmancenter.org"
    body         :msg_text => msg_text, :from_user => from_user
    content_type "text/html"

  end

  def discussion_notify(rotisserie_discussion)

    type_description = "discussion_notify"

    users = rotisserie_discussion.users

    if users.length > 0 then users = users.all(:conditions => "email_address IS NOT NULL") end
    
    rotisserie_discussion_id = rotisserie_discussion.id

    users.each do |user|
      discussion_tracker_hash = {
        :rotisserie_discussion_id => rotisserie_discussion.id,
        :user_id => user.id,
        :notify_description => type_description
      }

      if !NotificationTracker.exists?(discussion_tracker_hash)
        NotificationTracker.create(discussion_tracker_hash)
      end
    end

        recipients users.collect {|user| user.email_address unless user.email_address.blank? }
        subject      "Rotisserie Discussion Notification"
        from "noreply@berkmancenter.org"
        body         :rotisserie_discussion_id => rotisserie_discussion_id
        content_type "text/html"

  end

  def discussion_late_notify(rotisserie_discussion, user)

    type_description = "discussion_late_notify"
    rotisserie_discussion_id = rotisserie_discussion.id

      discussion_tracker_hash = {
        :rotisserie_discussion_id => rotisserie_discussion.id,
        #:post_id => post.id,
        :user_id => user.id,
        :notify_description => type_description
      }

      if !NotificationTracker.exists?(discussion_tracker_hash)
        NotificationTracker.create(discussion_tracker_hash)
      end

    to_user = user

    recipients to_user.email_address
    subject      "Rotisserie Discussion Notification"
    from "noreply@berkmancenter.org"
    body         :rotisserie_discussion_id => rotisserie_discussion_id
    content_type "text/html"

  end

  def assignment_notify(rotisserie_discussion, user)

    to_user = user
    rotisserie_discussion_id = rotisserie_discussion.id

    type_description = "assignment_notify"

      discussion_tracker_hash = {
        :rotisserie_discussion_id => rotisserie_discussion.id,
        #:post_id => post.id,
        :user_id => user.id,
        :notify_description => type_description
      }

      if !NotificationTracker.exists?(discussion_tracker_hash)
        NotificationTracker.create(discussion_tracker_hash)
      end

    recipients to_user.email_address
    subject      "Rotisserie Assignment Notification"
    from "noreply@berkmancenter.org"
    body         :rotisserie_discussion_id => rotisserie_discussion_id
    content_type "text/html"

  end

  def assignment_late_notify(rotisserie_discussion, user)

    to_user = user
    rotisserie_discussion_id = rotisserie_discussion.id

    type_description = "assignment_late_notify"

      discussion_tracker_hash = {
        :rotisserie_discussion_id => rotisserie_discussion.id,
        #:post_id => post.id,
        :user_id => user.id,
        :notify_description => type_description
      }

      if !NotificationTracker.exists?(discussion_tracker_hash)
        NotificationTracker.create(discussion_tracker_hash)
      end

    recipients to_user.email_address
    subject      "Rotisserie Late Assignment Notification"
    from "noreply@berkmancenter.org"
    body         :rotisserie_discussion_id => rotisserie_discussion_id
    content_type "text/html"

  end

  def completed_notify(rotisserie_discussion)

    users = rotisserie_discussion.users.all(:conditions => "email_address IS NOT NULL")
    rotisserie_discussion_id = rotisserie_discussion.id

    type_description = "completed_notify"

    users.each do |user|
      discussion_tracker_hash = {
        :rotisserie_discussion_id => rotisserie_discussion.id,
        :user_id => user.id,
        :notify_description => type_description
      }

      if !NotificationTracker.exists?(discussion_tracker_hash)
        NotificationTracker.create(discussion_tracker_hash)
      end
    end

        recipients users.collect {|user| user.email_address unless user.email_address.blank? }
        subject      "Rotisserie Completed Notification"
        from "noreply@berkmancenter.org"
        body         :rotisserie_discussion_id => rotisserie_discussion_id
        content_type "text/html"

  end

end
