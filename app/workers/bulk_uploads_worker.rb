class BulkUploadsWorker < Workling::Base
  
  def send_import_s(options)
    f = File.read('/Users/timcase/Sites/h2o/dbsession.txt')
    DropboxH2o.do_import(Case, f, BulkUpload.create!, User.find(415))
  end
  
  def send_import(options)
    bulk_upload = BulkUpload.find(options[:bulk_upload_id])
    user = User.find(options[:user_id])
    DropboxH2o.do_import(Case, 
                        options[:dropbox_session], 
                        bulk_upload,
                        user)
  end
end
