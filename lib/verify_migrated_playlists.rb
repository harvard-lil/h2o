module VerifyMigratedPlaylists
  class << self

    def verify
      results = {}

      # only doing updated at on jan 3rd for now.... presumably they would have noticed? Cause now it just shows all changes and they could be purposeful
      casebooks = Content::Casebook.where.not(playlist_id: nil).where(ancestry: nil).where(updated_at: DateTime.new(2018, 1, 3)..DateTime.new(2018, 1, 4))
      # irb(main):084:0> a.keys
      # => [18234, 17378, 20733, 18813, 23698, 23461, 22079, 24799, 26260, 28565]
      # irb(main):085:0> a.keys.count
      # => 10
      # casebooks = Content::Casebook.where.not(playlist_id: nil).where(ancestry: nil)
      # => 44
      # irb(main):095:0> a.keys
      # => [16133, 16530, 16723, 18234, 19353, 23052, 18560, 18672, 17493, 23114, 27225, 29980, 17378, 17751, 20926, 16066, 19750, 20733, 20611, 18813, 20234, 18331, 24680, 20414, 19006, 22411, 23698, 23461, 26936, 22079, 24172, 24799, 26562, 25610, 23303, 23416, 26260, 28024, 27674, 28325, 28565, 32567, 32667, 21268]

      casebooks.each do |casebook|
        result = VerifySinglePlaylist.verify(casebook.id)

        if result[:mismatched].present?
          results[casebook.id] = {mismatched: result[:mismatched], missing_items: result[:items_without_resources]}
        end
      end

      results
    end
  end
end
