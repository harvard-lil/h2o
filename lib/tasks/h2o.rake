namespace :h2o do

  task(:parse_test_new => :environment) do
    c = Case.find 5
    doc = Nokogiri::HTML.parse(c.content)
    doc.xpath('//*').each do |child|
      child.children.each do|c|
        if c.class == Nokogiri::XML::Text && ! c.content.blank?
          text_content = c.content.split.map{|word|"<tt>" + word + ' </tt>'}.join(' ')
          c.swap(text_content)
        end
      end
    end
    class_counter = 1
    doc.xpath('//tt').each do |n|
      n['id'] = "t#{class_counter}"
      class_counter +=1
    end
    puts doc.xpath("//html/body/*").to_s
  end

  desc 'Temporary case import'
  task(:temp_import_cases => :environment) do
    metadata_hash = {}
    FasterCSV.foreach("#{RAILS_ROOT}/tmp/cases/torts-metadata.csv", {:headers => :first_row, :header_converters => :symbol}) do |row|
      row_hash = row.to_hash
      metadata_hash[row_hash[:filename]] = row_hash
    end

#    puts metadata_hash.inspect
    Dir.glob("#{RAILS_ROOT}/tmp/cases/*.html").each do |file|
      basename = Pathname(file).basename.to_s
      if ! metadata_hash[basename].blank?
        c = Case.new()
        c.short_name = metadata_hash[basename][:short_name]
        c.full_name = metadata_hash[basename][:short_name]
        c.tag_list = metadata_hash[basename][:tags]
        tmp_content = File.read(file)
        tmp_content.gsub!(/<\/?(body|head|html)>/i,'')
#        tmp_content.gsub!(/<center>/i,'<div style="text-align: center;">')
#        tmp_content.gsub!(/<\/center>/i,'</div>')
#        tmp_content.gsub!(/<small>/i,'<div style="font-size: smaller;">')
#        tmp_content.gsub!(/<\/small>/i,'</div>')
        c.content = Iconv.iconv('UTF-8','ISO-8859-1',tmp_content)[0]
        c.save
      else
        puts "#{basename} didn't have an entry in the metadata hash"
      end
    end
  end

  desc 'Test case import'
  task(:import_cases => :environment) do
    c = Case.new()
    doc = Nokogiri::XML(File.open(RAILS_ROOT + '/doc/design/sample_case.xml'))

    c.current_opinion = (doc.xpath('//Case/CurrentOpinion').text == 'False') ? false : true
    
    c.short_name = doc.xpath('//Case/ShortName').text
    c.full_name = doc.xpath('//Case/ShortName').text
    c.decision_date = Time.parse(doc.xpath('//Case/DecisionDate').text)
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
      c.case_docket_numbers << CaseDocketNumber.find_or_create_by_docket_number(docket.text)
    end

    c.party_header = doc.xpath('//Case/PartyHeader').text
    c.lawyer_header = doc.xpath('//Case/LawyerHeader').text
    c.header_html = doc.xpath('//Case/HeaderHtml').text

    c.content = "#{doc.xpath('//Case/HeaderHtml').text} #{doc.xpath('//Case/CaseHtml').text}"

    puts c.inspect
    c.save!
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
