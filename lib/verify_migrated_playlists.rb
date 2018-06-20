module VerifyMigratedPlaylists
  class << self

    def verify
      bad_casebooks = []
      bad_casebook_items = []

      ## Find way to put query inside of where query 

      Content::Casebook.where.not(playlist_id: nil).where(ancestry: nil).each do |casebook|
        result = VerifySinglePlaylist.verify(casebook.id)

        if result[:mismatched]
          binding.pry
          bad_casebooks << casebook.id
        end

        if result[:items_without_resources].present?
          bad_casebook_items << {casebook_id: casebook.id, items: result[:items_without_resources]}
        end
      end

      puts "*******"
      puts bad_casebooks
      puts "******"
    end
  end
end
