class RotisserieAssignment < ActiveRecord::Base
  acts_as_authorization_object

  belongs_to :rotisserie_discussion
  belongs_to :rotisserie_post
  belongs_to :user


  def open?
    return self.round == self.rotisserie_discussion.get_current_round
  end

  #method returns true if post has a response
  def responded?
    return Post.exists?(:parent_id => self.post_id, :user_id => self.user_id)
  end

  def get_response_post
    nextround = self.post.round + 1
    post = Post.find_by_parent_id_and_user_id(self.post_id, self.user_id)
    return post
  end


end
