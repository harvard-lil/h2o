module RailsAdmin
  module Config
    module Actions
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
      field :content, :ck_editor
    end
  end

  config.model 'Collage' do
    list do
      field :name
      field :public
      field :user
      field :created_at
    end
  end

  config.model 'Playlist' do
    list do
      field :name
      field :public
      field :user
      field :created_at
    end
  end

  config.model 'Media' do
    list do
      field :name
      field :public
      field :user
      field :created_at
    end
  end

  config.model 'TextBlock' do
    label 'Text'
    list do
      field :name
      field :public
      field :user
      field :created_at
    end
  end

  config.model 'Default' do
    label 'Link'
    list do
      field :name
      field :url
      field :public
      field :user
      field :created_at
    end
  end

  config.model 'Case' do
    list do
      field :display_name
      field :public
      field :user
      field :user
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
      field :institutions
    end
  end
end
