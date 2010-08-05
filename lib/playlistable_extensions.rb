module PlaylistableExtensions

  module ClassMethods
    def playlistable?
      true
    end

    def playlisting_name
      case class_name
      when "QuestionInstance"
        "Question Tool"
      else
        class_name.titleize
      end
    end

  end

  module InstanceMethods
    def playlistable?(current_user = nil)
      true
    end
  end
end
