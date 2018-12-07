module RailsAdmin
  module Config
    module Actions
      class ShowInApp < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :visible? do
          authorized?
        end

        register_instance_option :member do
          true
        end

        register_instance_option :controller do
          proc do
            if @object.is_a?(Page)
              redirect_to "/p/#{@object.slug}"
            elsif @object.class == Content::Casebook
              redirect_to main_app.layout_casebook_path(@object.id)
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

      class ManageCollaborators < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :visible? do
          authorized?
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :post, :delete]
        end

        register_instance_option :controller do
          Proc.new do
            if request.get? && params[:search].present? # searching users
              user_ids = @object.collaborators.pluck(:user_id)
              users = User.where("email_address LIKE ? OR attribution LIKE ? OR title LIKE ?", "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%").collect { |u| { id: u.id, display: u.display, affiliation: u.affiliation, email_address: u.email_address, verified_professor: u.verified_professor} }
              @users = users.select {|user| user_ids.exclude? user[:id] } # only show users that aren't already collaborators

              if @users.empty?
                @search_term = params[:search]
                @no_results = true
              end
            elsif request.delete? # deleting a collaborator
              collaborator_id = params[:button]
              collaborator = Content::Collaborator.find(collaborator_id)

              if ! collaborator.destroy
                flash[:error] = collaborator.errors.full_messages.to_sentence
              end

            elsif request.post? # adding a collaborator
              user_id = params[:button].to_i
              role = params[:role].downcase

              new_collaborator = @object.collaborators.new(user_id: user_id, role: role)
              
              if ! new_collaborator.save
                flash[:error] = new_collaborator.errors.full_messages.to_sentence
              end
            end
          end
        end

        register_instance_option :link_icon do
          'icon-lock'
        end
      end
    end
  end
end

RailsAdmin.config do |config|
  config.parent_controller = '::ApplicationController'
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

    import
    export

    edit
    new

    delete
    manage_collaborators
    show_in_app
  end

  config.included_models = ['Content::Casebook', 'Case', 'User', 'TextBlock', 'Default', 'Page', 'CaseCourt']

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

  config.model 'TextBlock' do
    label 'Text'
    list do
      filters [:name, :public, :user_id, :created_at]
      field :name
      field :public
      field :user_id do 
        filterable true
      end
      field :created_at
    end
    edit do
      field :name
      field :public
      field :content, :ck_editor
      field :description
    end
  end

  config.model 'Default' do
    label 'Link'
    list do
      filters [:name, :url, :public, :user_id, :created_at]
      field :name
      field :url do
        filterable true
      end
      field :public
      field :user_id do
        filterable true
      end
      field :created_at
    end
    edit do
      field :name
      field :url
      field :public
    end
  end

  config.model 'Case' do
    list do
      field :name_abbreviation
      field :public
      field :created_at
    end

     show do 
      field :capapi_id
    end

    edit do
      field :public
      field :name_abbreviation
      field :name
      field :decision_date
      field :case_court { nested_form false }
      field :citations
      field :docket_number
      field :content, :ck_editor
      field :resource_links do
        label "Used in Casebooks"
        read_only true
        pretty_value do
          bindings[:object].resource_links
        end
      end
    end
  end

  config.model 'Content::Casebook' do
    list do
      field :title
      field :owner
    end

    edit do
      field :title
      field :subtitle
      field :headnote, :ck_editor
      field :public
      field :ancestry do
        read_only true
      end
    end
  end

  config.model 'User' do
    list do
      field :id
      field :attribution
      field :affiliation
      field :email_address
      field :created_at
      field :verified_professor
      field :professor_verification_requested
      field :login_count
      field :last_login_at
    end

    edit do
      field :verified_email
      field :verified_professor
      field :professor_verification_requested
      field :attribution
      field :affiliation
      field :email_address
      field :set_password do
        label "New Password"
        help "Optional. Leave blank if not changing password."
      end
      field :last_login_at
      field :url
    end
  end
end
