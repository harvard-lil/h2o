module RailsAdmin
  module Config
    module Actions
      class ViewInApp < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :visible? do
          authorized? && ([Collage, Playlist].include?(bindings[:object].class) || (bindings[:object].public && bindings[:object].active))
        end

        register_instance_option :member do
          true
        end
        
        register_instance_option :controller do
          proc do
            if @object.is_a?(Media)
              redirect_to main_app.media_path(@object)
            else
              redirect_to main_app.url_for(@object)
            end
          end
        end

        register_instance_option :link_icon do
          'icon-eye-open'
        end

        register_instance_option :pjax? do
          false
        end
      end
    end
  end
end

module RailsAdmin
  module Config
    module Actions
      class EditInApp < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :visible? do
          authorized? && [Case, Default, Media, TextBlock].include?(bindings[:object].class)
        end

        register_instance_option :member do
          true
        end

        register_instance_option :controller do
          proc do
            redirect_to main_app.send("edit_#{@object.class.to_s.underscore}_path", @object)
          end
        end

        register_instance_option :link_icon do
          'icon-pencil'
        end

        register_instance_option :pjax? do
          false
        end
      end
    end
  end
end

RailsAdmin.config do |config|
  config.current_user_method do
    current_user
  end
  config.authorize_with :cancan

  config.actions do
    dashboard                     # mandatory
    index                         # mandatory
    bulk_delete
    
    show
    edit
    new
    import
    export

    delete
    edit_in_app
    view_in_app
  end

  config.included_models = ['Playlist', 'Collage', 'Case', 'User', 'TextBlock', 'Media', 'Default', 'Institution']

  config.model 'Collage' do
    list do
      field :name
      field :active
      field :public
      field :karma
    end
  end

  config.model 'Playlist' do
    list do
      field :name
      field :active
      field :public
      field :karma
    end
  end

  config.model 'Media' do
    list do
      field :name
      field :active
      field :public
      field :karma
    end
  end

  config.model 'TextBlock' do
    label 'Text'
    list do
      field :name
      field :active
      field :public
      field :karma
    end
  end

  config.model 'Default' do
    label 'Link'
    list do
      field :name
      field :url
      field :active
      field :public
      field :karma
    end
  end

  config.model 'Case' do
    list do
      field :short_name
      field :full_name
      field :active
      field :public
      field :karma
    end
  end

  config.model 'Institution' do
    list do
      field :name
      field :users
    end
  end

  config.model 'User' do
    object_label_method do
      :custom_label_method
    end
    list do
      field :id
      field :login
      field :email_address
      field :institutions
    end
  end
end
