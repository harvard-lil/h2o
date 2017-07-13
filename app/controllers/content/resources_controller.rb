require 'net/http'
require 'uri'

class Content::ResourcesController < Content::NodeController
  def show
  end

  def annotate
    @editable = true
    render 'show'
  end

  def export
    @resource = Content::Resource.find params[:resource_id]

    html = render_to_string layout: 'export'
    respond_to do |format|
      format.pdf {
        send_file Export::PDF.save(html, annotations: params[:annotations] != 'false'), type: 'application/pdf', filename: helpers.truncate(@resource.title, length: 45, omission: '-', separator: ' ') + '.pdf', disposition: :inline
      }
      format.docx {
        send_file Export::DOCX.save(html, annotations: params[:annotations] != 'false'), type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', filename: helpers.truncate(@resource.title, length: 45, omission: '-', separator: ' ') + '.docx', disposition: :inline
      }
      format.html { render body: html, layout: false }
    end
  end

  private

  def page_title
    if @resource.present?
      if action_name == 'edit'
        I18n.t 'content.titles.resources.edit', casebook_title: @casebook.title, section_title: @resource.title, ordinal_string: @resource.ordinal_string
      else
        I18n.t 'content.titles.resources.show', casebook_title: @casebook.title, section_title: @resource.title,  ordinal_string: @resource.ordinal_string
      end
    else
      I18n.t 'content.titles.resources.read', casebook_title: @casebook.title, section_title: @resource.title,  ordinal_string: @resource.ordinal_string
    end
  end
end
