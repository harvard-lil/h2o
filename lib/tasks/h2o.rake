namespace :h2o do

  desc 'Generate playlist PDFs'
  task(:gen_playlist_pdfs => :environment) do
    permutations = Playlist.cache_options
    Playlist.find(:all, :conditions => ['public is true'], :order => 'updated_at desc').each do |pl|
      permutations.each do|pm|
        url = "http://h2odev.law.harvard.edu/playlists/#{pl.id}/export?#{pm}"
        clean_cgi = CGI.escape(pm)
        output_file = "#{RAILS_ROOT}/tmp/cache/playlist_#{pl.id}.pdf?#{clean_cgi}"
        if !FileTest.exists?(output_file)
          puts "Generating PDF for: #{url}"
          file = File.new(output_file, "w+")
          system("#{RAILS_ROOT}/pdf/wkhtmltopdf -B 25.4 -L 25.4 -R 25.4 -T 25.4 --footer-html #{RAILS_ROOT}/pdf/playlist_footer.html \"#{url}\" #{file.path}")
          sleep 2
        end
      end
    end
    
  end

  desc 'Test case import'
  task(:import_cases => :environment) do

    # -i --add-xml-decl n --doctype omit --show-body-only true
    TidyFFI::Tidy.default_options.add_xml_decl = false
    TidyFFI::Tidy.default_options.doctype = 'omit'
    TidyFFI::Tidy.default_options.show_body_only = 1
    TidyFFI::Tidy.default_options.output_xhtml = true

    #metadata_hash = {}
    #FasterCSV.foreach("#{RAILS_ROOT}/tmp/cases/torts-metadata.csv", {:headers => :first_row, :header_converters => :symbol}) do |row|
#      row_hash = row.to_hash
#      metadata_hash[row_hash[:filename]] = row_hash
#    end

    Dir.glob("#{RAILS_ROOT}/tmp/cases/*.xml").each do |file|
      c = Case.new()
      basename = Pathname(file).basename.to_s
#      puts file
      doc = Nokogiri::XML.parse(File.open(file))
#      unless metadata_hash[basename].blank?
#        c.tag_list = metadata_hash[basename][:tags]
#      end

      c.tag_list = 'conlaw'
      c.current_opinion = (doc.xpath('//Case/CurrentOpinion').text == 'False') ? false : true

      c.short_name = doc.xpath('//Case/ShortName').text
      c.full_name = doc.xpath('//Case/ShortName').text

      #Done like this because Time.parse doesn't deal with dates before 1901
      date = doc.xpath('//Case/DecisionDate').text
      unless date.blank?
        date_array = date.split(/\D/)
        c.decision_date = "#{date_array[2]}-#{date_array[0]}-#{date_array[1]}"
      end
      c.author = doc.xpath('//Case/Author').text

      cj = CaseJurisdiction.find_or_create_by_abbreviation_and_name(
        doc.xpath('//Case/Jurisdiction/CourtAbbreviation').text, 
        doc.xpath('//Case/Jurisdiction/CourtName').text
      )

      c.case_jurisdiction = cj

      doc.xpath('//Case/Citations/Citation').each do |cite|
        c.case_citations << CaseCitation.find_or_create_by_volume_and_reporter_and_page(
          cite.xpath('Volume').text || '', 
          cite.xpath('Reporter').text || '',
          cite.xpath('Page').text || ''
        )
      end

      doc.xpath('//Case/DocketNumbers/DocketNumber').each do |docket|
        unless docket.text.blank?
          c.case_docket_numbers << CaseDocketNumber.find_or_create_by_docket_number(docket.text)
        end
      end

      c.party_header = doc.xpath('//Case/PartyHeader').text
      c.lawyer_header = doc.xpath('//Case/LawyerHeader').text
      c.header_html = doc.xpath('//Case/HeaderHtml').text

#      puts
#      puts "Content of #{file}, pre-stripping: "
#      puts  "#{doc.xpath('//Case/HeaderHtml').text} #{doc.xpath('//Case/CaseHtml').text}"

      tidy_content = TidyFFI::Tidy.new("#{doc.xpath('//Case/HeaderHtml').text} #{doc.xpath('//Case/CaseHtml').text}")

      c.content = tidy_content.clean
#      puts
#      puts "Content of #{file}, post-stripping: "
#      puts c.content

#      puts
#      puts

      if c.save
#        puts "Successfully imported: #{file}"
      else 
        puts "FAILED: #{file}"
      end
    end
      Sunspot.commit_if_dirty
  end

  desc 'Send rotisserie invitations'
  task(:send_invites => :environment) do
    notification_invites = NotificationInvite.all(:conditions => {:sent => false, :resource_type => "RotisserieInstance"})

    notification_invites.each do |notification_invite|
      Notifier.deliver_rotisserie_invite_notify(notification_invite)
      notification_invite.update_attributes({:sent => true})
    end
  end

end
