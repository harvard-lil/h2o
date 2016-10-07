module RailsAdmin
  module Config
    module Actions
      class DeletePlaylistNested < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)
        register_instance_option :visible? do
          authorized?
        end
        register_instance_option :member do
          true
        end
        register_instance_option :http_methods do
          [:get, :post]
        end
        register_instance_option :controller do
          proc do #Proc.new do
            if request.get?
              #do nothing
            elsif request.post?  #delete?
              message = Playlist.destroy_playlist_and_nested(@object)
              flash[:notice] = message #"Playlist #{@object.name} and nested items have been deleted."
              redirect_to "/admin/playlist"
            end
          end
        end

        register_instance_option :link_icon do
          'icon-trash'
        end
      end
      class AggregateItems < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :visible? do
          authorized?
        end

        register_instance_option :collection do
          true
        end
        register_instance_option :http_methods do
          [:get, :post]
        end
        register_instance_option :controller do
          Proc.new do
            if request.post?
              if params[:from] == '' || params[:to] == ''
                @error = 'You must select a starting and end date.'
              else
                start_filter = Date.strptime(params[:from], "%m/%d/%Y").beginning_of_day
                end_filter = Date.strptime(params[:to], "%m/%d/%Y").end_of_day
                @created = @abstract_model.where(created_at: start_filter..end_filter).select(:id, :created_at).group_by(&:month)
                @deleted = DeletedItem.where(item_type: params[:model_name].capitalize, deleted_at: start_filter..end_filter).select(:id, :deleted_at).group_by(&:month)
                @dates = (@created.keys + @deleted.keys).uniq.sort
                @totals_created = {}
                @totals_deleted = {}
                created_total = 0
                deleted_total = 0
                @dates.each do |date|
                  @created[date] = [] if !@created.has_key?(date) 
                  created_total += @created[date].size
                  @totals_created[date] = created_total 
                  
                  @deleted[date] = [] if !@deleted.has_key?(date) 
                  deleted_total += @deleted[date].size
                  @totals_deleted[date] = deleted_total 
                end
              end
            end
          end
        end

        register_instance_option :link_icon do
          'icon-eye-open'
        end
      end
    end
  end
end

module RailsAdmin
  module Config
    module Actions
      class ViewInApp < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :visible? do
          authorized?
        end

        register_instance_option :member do
          true
        end
        
        register_instance_option :controller do
          proc do
            if @object.is_a?(Media)
              redirect_to main_app.media_path(@object)
            elsif @object.is_a?(Page)
              redirect_to "/p/#{@object.slug}"
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
          authorized?
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
  config.navigation_static_links = {
    'Playlist Importer' => '/playlists/import',
    'Empty Playlists' => '/playlists/empty',
    'Empty Playlists CSV' => '/playlists/empty.csv',
  }
  config.current_user_method do
    current_user
  end
  config.authorize_with :cancan

  config.actions do
    dashboard                     # mandatory
    index                         # mandatory
    bulk_delete

    aggregate_items 
    import
    export

    edit
    new

    delete
    delete_playlist_nested
    edit_in_app
    view_in_app
  end

  config.included_models = ['Playlist', 'Collage', 'Case', 'User', 'TextBlock', 'Media', 'Default', 'Institution', 'Page']

  config.model 'Page' do
    list do
      field :slug
      field :page_title
      field :updated_at
    end
    edit do
      field :slug
      field :page_title
      field :footer_link do
        help "If checked, this will show in the footer navigation"
      end
      field :footer_sort 
      field :footer_link_text do
        help "Anchor text for footer link"
      end
      field :is_user_guide do
        help "If check, this will have sidebar navigation and show in the user guide sidebar navigation"
      end
      field :user_guide_sort
      field :user_guide_link_text do
        help "Anchor text for user guide sidebar navigation"
      end
      field :content, :ck_editor
    end
  end

  config.model 'Collage' do
    label 'Annotated Item'
    list do
      field :name
      field :public
      field :user do
        searchable [:login, :email_address]
      end
      field :created_at
    end
  end

  config.model 'Playlist' do
    list do
      field :name
      field :public
      field :user do
        searchable [:login, :email_address]
      end
      field :created_at
    end
  end

  config.model 'Media' do
    list do
      field :name
      field :public
      field :user do
        searchable [:login, :email_address]
      end
      field :created_at
    end
  end

  config.model 'TextBlock' do
    label 'Text'
    list do
      field :name
      field :public
      field :user do
        searchable [:login, :email_address]
      end
      field :created_at
    end
  end

  config.model 'Default' do
    label 'Link'
    list do
      field :name
      field :url
      field :public
      field :user do
        searchable [:login, :email_address]
      end
      field :created_at
    end
  end

  config.model 'Case' do
    list do
      field :display_name
      field :public
      field :created_at
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
      field :created_at
      field :verified
    end

    edit do
      field :verified do
        label "Is user verified?"
        help "Setting a user to verified will automatically send them a welcome email."
      end
      field :login
      field :email_address
      field :set_password do
        label "New Password"
        help "Optional. Leave blank if not changing password."
      end

      include_all_fields
      exclude_fields :password, :password_confirmation, :crypted_password, :password_salt, :persistence_token, :oauth_token, :oauth_secret, :bookmark_id, :perishable_token
      #fields :set_password, :email_address
      #field :email_address
    end
  end
end
