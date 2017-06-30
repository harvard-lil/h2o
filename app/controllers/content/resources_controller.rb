require 'net/http'
require 'uri'

class Content::ResourcesController < ApplicationController
  layout 'export'

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
end
