module VerifyMigratedPlaylists
  class << self

  def verify
    casebooks.each do |casebook|
      VerifySinglePlaylist.verify casebook
    end
  end
end
