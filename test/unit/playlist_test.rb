require File.expand_path("../../test_helper", __FILE__)

class PlaylistTest < ActiveSupport::TestCase
  
  def test_true
    assert true
  end              
  
  def setup
    @user1 = FactoryGirl.build(:user) 
    @user1.save(false)
    @user2 = FactoryGirl.build(:user) 
    @user2.save(false)
    Playlist.class_eval do
      def maybe_auto_index
      end     
    end
    @playlist = Playlist.create!(:title => 'test playlist', :name => 'test playlist')    
    @playlist.accepts_role!(:owner, @user1)
    @playlist.accepts_role!(:creator, @user1)
              
    Case.class_eval do
      def maybe_auto_index
      end
    end 
        
    new_case = Case.create!(:short_name => "Case Name", :content => "yada yada yada")
    new_case.accepts_role!(:owner, @user1)
    new_case.accepts_role!(:creator, @user1)
    
    Collage.class_eval do
      def maybe_auto_index
      end
    end
    collage = Collage.create!(:name => "test collage", :description => 'test collage', 
                              :annotatable => new_case)                              
    collage.accepts_role!(:owner, @user1)
    collage.accepts_role!(:creator, @user1)    
    item_collage = ItemCollage.create!(:name => "my collage", :actual_object => collage, :url => 'http://google.com')               
    PlaylistItem.create!(:playlist => @playlist, :resource_item => item_collage)
    
  end
  
  # def test_play_list_items
  #   assert_equal '', @playlist.playlist_items.first.resource_item.actual_object
  # end
  
  # def test_first_user_has_playlist
  #   assert_equal 1, @user1.playlists.count
  # end
  # 
  # def test_responds_to_push
  #   assert_respond_to Playlist.new, :push! 
  # end
  
  def test_push!
    assert_equal 0, @user2.playlists.count
    @playlist.push!(:recipient => @user2)
    @user2.reload
    assert_equal 1, @user2.playlists.count
  end
  
  #u = User.find     
  #u.push_playlists
  #self.playlists.each do |playlist|
  #playlist.push!(:recipient => user)
  #self.playlists
end
