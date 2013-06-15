class Notifier < ActionMailer::Base
  include AuthUtilities
  include Authorship

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

  def rotisserie_invite_notify(notification_invite)

    rotisserie_instance = RotisserieInstance.find(notification_invite.resource_id)

    recipients notification_invite.email_address
    subject      "Rotisserie Invitation"
    from "noreply@berkmancenter.org"
    body         :rotisserie_instance_id => rotisserie_instance.id, :tid => notification_invite.tid
    content_type "text/html"

  end

  def case_notify_updated(updated_case)

    recipients updated_case.users.map(&:email_address).uniq
    subject "Case Updated"
    from "noreply@berkmancenter.org"
    body  :case => updated_case
    content_type "text/html"
  end

  def case_notify_approved(approved_case)

    recipients approved_case.users.map(&:email_address).uniq
    subject approved_case.case_request ? "Case Request Approved" : "Case Approved"
    from "noreply@berkmancenter.org"
    body  :case => approved_case
    content_type "text/html"
  end

  def case_request_notify_updated(case_request)

    recipients case_request.users.map(&:email_address).uniq
    subject "Case Request Updated"
    from "noreply@berkmancenter.org"
    body  :case_request => case_request
    content_type "text/html"
  end

  def case_request_notify_rejected(case_request)

    recipients case_request.users.map(&:email_address).uniq
    subject "Case Request Not Accepted"
    from "noreply@berkmancenter.org"
    body  :case_request => case_request
    content_type "text/html"
  end

  def case_notify_rejected(rejected_case)

    recipients rejected_case.users.map(&:email_address).uniq
    subject "Case Not Accepted"
    from "noreply@berkmancenter.org"
    body  :case => rejected_case
    content_type "text/html"
  end

  def password_reset_instructions(user)

    subject       "Password Reset Instructions"
    from          "noreply@berkmancenter.org"
    recipients    user.email_address
    sent_on       Time.now
    body          :edit_password_reset_url => edit_password_reset_url(user.perishable_token)
  end

  def logins(users)
    recipients users.map(&:email_address).uniq
    subject    "Logins"
    from       "noreply@berkmancenter.org"
    sent_on    Time.now
    body       :new_password_reset_url => new_password_reset_url, :users => users
  end

  def cases_list
    recipients ['h2o@cyber.law.harvard.edu']
    subject    "List of All Cases #{Time.now.to_s(:simpledate)}"
    from       "noreply@berkmancenter.org"
    sent_on    Time.now
    attachment :content_type => 'text/tab-separated-values',
               :body => Case.to_tsv,
               :filename => "cases_list_#{Time.now.strftime("%Y%m%d%H%M")}"
  end

  def playlist_push_completed(user, playlist)
    recipients [user.email_address]
    subject    "Push of Playlist #{playlist.name} completed"
    from       "noreply@berkmancenter.org"
    sent_on    Time.now
  end

  def bulk_upload_completed(user, bulk_upload)
    recipients [user.email_address]
    subject    "Bulk Upload completed"
    from       "noreply@berkmancenter.org"
    sent_on    Time.now
    body       :bulk_upload => bulk_upload, :bulk_upload_url => bulk_upload_url(bulk_upload)
  end
end
