class BulkUploadJob < ApplicationJob
  queue_as :default
  # To run via console:
  # BulkUploadsWorker.send_import(:dropbox_session => User.find(231).dropbox_access_token, :user_id => 231, :bulk_upload_id => 290)

  def perform(options)
    logger.debug "START IMPORT******************************************"
    logger.debug "bulkuploads_worker.rb (9): send import mesage received"
    bulk_upload = BulkUpload.find(options[:bulk_upload_id])
    logger.debug "bulkuploads_worker.rb (11): bulk upload found"
    user = User.find(options[:user_id])
    logger.debug "bulkuploads_worker.rb (13): user found"
    Dropbox::H2o.do_import(Case,
                        options[:dropbox_session],
                        bulk_upload,
                        user)
    logger.debug "bulkuploads_worker.rb (18): do_import finished"
    logger.debug "END IMPORT*******************************************"
  end
end
