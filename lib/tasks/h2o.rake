namespace :h2o do

  desc 'Test case import'
  task(:import_cases => :environment) do
    c = Case.new(:short_name => 'Short Name', :full_name => 'Full Name')
    c.content = File.open(RAILS_ROOT + '/doc/design/sample_case.html').read
    c.save!
  end

  desc 'Send rotisserie invitations'
  task(:send_invites => :environment) do
    notification_invites = NotificationInvite.all(:conditions => {:sent => false, :resource_type => "RotisserieInstance"})

    notification_invites.each do |notification_invite|
      Notifier.deliver_rotisserie_invite_notify(notification_invite)
      notification_invite.update_attributes({:sent => true})
    end
  end

end
