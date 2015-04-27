require 'uri'

class PlaylistExporter
  include Rails.application.routes.url_helpers

  class << self

    def export_as(request_url, params)
      #request_url will actually be the full request URI that is posting TO this page. We need
      # pieces of that that to construct the URL we are going to pass to wkhtmltopdf
      # target_url = "http://sskardal03.murk.law.harvard.edu:8000/playlists/19763/export"
      command = generate_command(request_url, params)
      exit_code = nil
      command_output = ''
      Open3.popen2e(*command) {|i,out_err,wait_thread|
        out_err.each {|line| command_output += line}
        exit_code = wait_thread.value.exitstatus
      }

      #ASYNC
      #email the user either way
      #if it failed, email "sorry" message that we BCC to an admin (uniq error string they can grep for in logs?)
      #if it succeeded, email "here is your link" message

      if exit_code == 0
        command.last
      else
        Rails.logger.warn "Export failed for command: #{command}\nOutput: #{command_output}"
        false
      end

      # result = system(command)
      # # if result is true, the system call returned success. Else, check existstatus
      # Rails.logger.debug "result: '#{result}' -> '#{$?.exitstatus}'"
    end

    def forwarded_cookies(params)
      #TODO: Remove toc_levels from this list because we're going to switch to making
      # wkhtmltopdf generate the TOC
      allowed_export_options = %w(
        printtitle 
        printdetails 
        printparagraphnumbers 
        printannotations 
        printhighlights 
        hiddentext 
        fontface 
        fontsize
        toc_levels 
      )

      #TODO: This is a fake number used to trick the javascript into processing cookies
      cookies = {'user_id' => 42}  #TODO: remove javascript dependency on this in export.js
      cookies.merge!(params.slice(*allowed_export_options))
      cookies.map {|k,v| "--cookie #{k} #{sanitize_cookie(v)}"}.join(' ')
    end

    def generate_command(request_url, params)
      object_id = params['id']
      binary = 'wkhtmltopdf'
      hostname = URI(request_url).host  #=> "sskardal03.murk.law.harvard.edu"
      #TODO: See if we really need --javascript-delay, especially now that we're not
      #going to generate the TOC via the javascript hooks.
      options = "--custom-header-propagation --custom-header host #{hostname} "
      options += "--no-stop-slow-scripts --javascript-delay 1000 --debug-javascript "
      options += "--print-media-type --no-outline "
      cookie_string = forwarded_cookies(params)

      output_file_path = output_filename(object_id)
      prep_output_file_path(output_file_path)

      #output_file_url = output_filename_relative_path(output_file_path)
      target_url = get_target_url(request_url, object_id)
      
      Rails.logger.debug output_file_path
      #Rails.logger.debug output_file_url
      [binary, options, cookie_string, target_url, output_file_path,].join(' ').split
    end

    def prep_output_file_path(output_file_path)
      FileUtils.mkdir_p(File.dirname(output_file_path))
    end
  
    
    def get_target_url(request_url, id)
      uri = URI(request_url)
      #TODO: Use uri.host in production (murk needs sskardal03.murk.law.harvard.edu added to /etc/hosts)
      export_playlist_url(
                          :id => id,
                          :host => '128.103.64.117',
                          :port => uri.port
                          )
    end

    def output_filename_relative_path(full_path)
      begin
        full_path.match(%r{(/public/playlists/.+)$})[0]
      rescue => e
        raise "Failed to find output_filename_relative_path in #{full_path}"
      end
    end

    def output_filename(object_id)
      object_id.gsub!(/\D/, '')
      #TODO: adjust this path to match the current export URL style
      filename_hash = SecureRandom.hex(4)
      Rails.root.join(
                      'public',
                      'playlists',
                      object_id.to_s,
                      "playlist-#{object_id}-#{filename_hash}.pdf"
                      ).to_s
    end

    def sanitize_cookie(val)
      %Q|"#{ val.to_s.gsub(/\W/, '') }"|
    end

  end
end
