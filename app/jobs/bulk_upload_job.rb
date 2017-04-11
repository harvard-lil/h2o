class BulkUploadJob < ApplicationJob
  queue_as :default
  # To run via console:
  # BulkUploadsWorker.send_import(:dropbox_session => User.find(231).dropbox_access_token, :user_id => 231, :bulk_upload_id => 290)

  def perform(options)
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
