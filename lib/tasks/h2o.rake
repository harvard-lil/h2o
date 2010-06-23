namespace :h2o do

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
