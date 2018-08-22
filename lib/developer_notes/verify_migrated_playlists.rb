module VerifyMigratedPlaylists
  class << self

    def verify
      results = {}

      casebooks = Content::Casebook.where.not(playlist_id: nil).where(ancestry: nil)

      casebooks.each do |casebook|
        mismatched = VerifySinglePlaylist.verify(casebook.id)

        if mismatched.present?
          results[casebook.id] = mismatched
        end
      end

      results
    end
  end
end
