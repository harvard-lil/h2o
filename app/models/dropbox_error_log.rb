class DropboxErrorLog
  ERROR_LOG_NAME = 'error.log'
  ERROR_LOG_PATH = "/#{ERROR_LOG_NAME}"

  attr_reader :error_log

  def initialize(client)
    @client = client
  end


  def write(path, messages)
    self.get_or_initialize
    self.append(path, messages)
    self.put
    self.rm_temp_file
    true
  end


  def get_or_initialize
      @error_log = Tempfile.new(ERROR_LOG_NAME)
    begin
      @error_log.write(@client.get_file(ERROR_LOG_PATH))
    rescue DropboxError
    end
    true
  end

  def append(path, error_messages)
    @error_log.write(entry(path, error_messages))
  end

  def put
    clobber_existing_file = true
    @client.put_file(ERROR_LOG_PATH, @error_log.open, clobber_existing_file)
  end

  def rm_temp_file
    @error_log.unlink
  end

  def entry(path, error_messages)
    "#{path.ljust(30)}#{error_messages}\n"
  end
end
