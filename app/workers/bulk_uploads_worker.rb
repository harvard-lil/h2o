class BulkUploadsWorker < Workling::Base
  
  def send_import_s(options)
    f = File.read('/Users/timcase/Sites/h2o/dbsession.txt')
    DropboxH2o.do_import(Case, f, BulkUpload.create!, User.find(415))
  end
  
  def send_import(options)
    puts "START IMPORT******************************************\n"
    puts "bulkuploads_worker.rb (9): send import mesage received\n"
    bulk_upload = BulkUpload.find(options[:bulk_upload_id])
    puts "bulkuploads_worker.rb (11): bulk upload found\n"
    user = User.find(options[:user_id])
    puts "bulkuploads_worker.rb (13): user found\n"
    DropboxH2o.do_import(Case, 
                        options[:dropbox_session], 
                        bulk_upload,
                        user)
    puts "bulkuploads_worker.rb (18): do_import finished\n"
    puts "END IMPORT*******************************************\n"
  end
end
