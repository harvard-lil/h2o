class IframeController < BaseController
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
      when 'text_blocks', 'cases'
        resource_type.camelize.singularize.constantize.find(params.fetch(:id))
      else
        head :bad_request
      end
  end
end
