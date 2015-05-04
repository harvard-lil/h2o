class IframeController < ApplicationController
  caches_page :load, :show, :if => Proc.new { |c| c.instance_variable_get('@single_resource').try(:public?) }

  def load
  end

  def show
    render @single_resource, layout: false
  end

  private

  def action_check
    :show
  end
  
  def iframe?
    true
  end

  def load_single_resource
    resource_type = params.fetch(:type)
    @single_resource =
      case resource_type
      when 'playlists', 'collages'
        resource_type.singularize.capitalize.constantize.find(params.fetch(:id))
      else
        head :bad_request
      end
    case @single_resource
    when Playlist
      nested_ps = Playlist.includes(:playlist_items).where(id: @single_resource.all_actual_object_ids[:Playlist])
      @nested_playlists = nested_ps.inject({}) { |h, p| h["Playlist-#{p.id}"] = p; h }
    when Collage
      @layer_data = @single_resource.layer_data
    end
  end
end
