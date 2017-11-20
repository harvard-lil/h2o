module H2o::Test::Helpers::Files
  def expected_file_path filename
    env_subdir = if ENV['TRAVIS']
      'travis'
    else
      'osx'
    end
    Rails.root.join( 'test/files', env_subdir, filename)
  end
  def upload_file_path filename
    Rails.root.join( 'test/files/uploads', filename)
  end
end

# deterministic Word exports
class Zip::DOSTime
  def self.now
    new '2017'
  end
end
