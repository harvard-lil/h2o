class DropboxH2o
  FAILED_DIR_FILE_PATH = '/failed'
  def initialize
    new_session = DropboxSession.deserialize(File.read('dbsession.txt'))
    @client = DropboxClient.new(new_session, DROPBOXCONFIG[:access_type])
  end

  def copy_to_failed_dir(file_path)
    @client.file_copy(file_path, "#{FAILED_DIR_FILE_PATH}#{file_path}")
  end

  def import_file_paths
    res = @client.metadata('/')['contents'].map{|entry| entry['path']}
    res = res - excluded_file_paths
    res
  end

  def get_file(file_path)
    @client.get_file(file_path)
  end

  def write_error(path, error_messages)
    del =DropboxErrorLog.new(@client)
    del.write(path, error_messages)
  end

  def excluded_file_paths
    [FAILED_DIR_FILE_PATH, DropboxErrorLog::ERROR_LOG_PATH]
  end

end
