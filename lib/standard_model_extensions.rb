module StandardModelExtensions
  extend ActiveSupport::Concern

=begin
  included do
    #Class methods go here.
    # Validate text and string column lengths automatically, and for existence.
    to_validate = self.columns.reject{|col| ! [:string,:text].include?(col.type)}
    valid_output = ''
    to_validate.each do|val_col|
      valid_output += "validates_length_of :#{val_col.name}, :maximum => #{val_col.limit}, :allow_blank => #{val_col.null}\n"
      if ! val_col.null
        valid_output += "validates_presence_of :#{val_col.name}\n"
      end
    end

    #This seems ass-backwards, but works well.
    model.class_eval valid_output
  end
=end

  def current_user
    session = UserSession.find
    current_user = session && session.user
    return current_user
  end

  def owner?
    return self.user == current_user
  end

  def can_edit?
    return current_user.present? ? (current_user.has_role?(:superadmin) || self.owner?) : false
  end

  def stored(field)
    self.send(field)
  end

  def barcode_breakdown
    self.barcode.inject({}) { |h, b| h[b[:type].to_sym] ||= 0; h[b[:type].to_sym] += 1; h }
  end

  def playlists_included_ids
    PlaylistItem.find(:all, :conditions => { :actual_object_type => self.class.to_s, :actual_object_id => self.id }, :select => :playlist_id)
  end

  def barcode_bookmarked_added
    elements = []
    PlaylistItem.where({ :actual_object_id => self.id, :actual_object_type => self.class.to_s }).each do |item|
      next if item.playlist.nil?
      playlist = item.playlist
      if playlist.name == "Your Bookmarks"
        elements << { :type => "bookmark",
                              :date => item.created_at,
                              :title => "Bookmarked by #{playlist.user.display}",
                              :link => user_path(playlist.user) }
      elsif playlist.public
        elements << { :type => "add",
                              :date => item.created_at,
                              :title => "Added to playlist #{playlist.name}",
                              :link => playlist_path(playlist) }
      end
    end
    elements
  end

  def karma_display
    case karma
    when nil
      ''
    when 0
      ''
    when 1..9
      '1+'
    when 10..999
      "#{(karma.to_i/10)*10}+"
    else
      "#{(karma.to_i/100)*100}+"
    end
  end

  def user_display
    self.user.nil? ? nil : self.user.display
  end

  def root_user_display
    self.root.user.nil? ? nil : self.root.user.display
  end
  
  def root_user_id
    self.root.user_id
  end
end
