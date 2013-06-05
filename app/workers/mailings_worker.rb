class MailingsWorker < Workling::Base
  def send_mailing(options)
    Notifier.deliver_password_reset_instructions(User.find(415))
  end
  
  def send_import(options)
    f = File.read('/Users/timcase/Sites/h2o/dbsession.txt')
    DropboxH2o.do_import(Case, f, BulkUpload.create!, User.find(415))
  end
  
  def send_import_s(options)
    # bulk_upload = BulkUpload.find(options[:bulk_upload_id])
    user = User.find(options[:user_id])
    DropboxH2o.do_import(Case, 
                        options[:dropbox_session], 
                        BulkUpload.create!,
                        user)
  end
  
end
