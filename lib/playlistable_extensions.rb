module PlaylistableExtensions

  def self.included(model)
    model.class_eval do
      #instance Methods
      def playlistable?(current_user = nil)
        true
      end
    end

    model.instance_eval do
      #class methods
      def playlistable?
        true
      end
      def playlisting_name
        case self.to_s
        when "QuestionInstance"
          "Question Tool"
        else
          self.to_s.titleize
        end
      end
    end
  end
end
