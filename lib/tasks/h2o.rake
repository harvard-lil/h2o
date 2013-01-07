namespace :h2o do

  task(:steph_test => :environment) do
    require 'benchmark'
    Benchmark.bm do |x|
      x.report do
        5.times do
          Playlist.tag_list
        end
      end
    end
    Benchmark.bm do |x|
      x.report do
        5.times do
          b = Playlist.all.collect { |p| p.tag_list }.flatten
          c = b.inject({}) { |h, a| h[a] ||= 0; h[a]+=1; h }
          c.sort_by { |k, v| v }.reverse[0..25]
        end
      end
    end
  end

  desc 'Update user karma'
  task(:update_user_karma => :environment) do
    User.find_in_batches { |users| users.each { |u| u.update_karma } }
  end

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
        end
      end
    end
  end
 
  def deep_clone(playlist, creator, indent)
    cloned_playlist = playlist.clone
    cloned_playlist.accepts_role!(:owner, creator)
    cloned_playlist.accepts_role!(:creator, creator)
    cloned_playlist.tag_list = playlist.tag_list

    playlist.playlist_items.each do |pi|
      cloned_playlist_item = pi.clone
      cloned_playlist_item.accepts_role!(:owner, creator)
      cloned_resource_item = pi.resource_item.clone
      cloned_resource_item.accepts_role!(:owner, creator)
      if pi.resource_item.actual_object
        if pi.resource_item_type == 'ItemPlaylist'
          puts "#{indent}cloning playlist: #{pi.resource_item.actual_object}"
          cloned_object = deep_clone(pi.resource_item.actual_object, creator, "#{indent}\t")
        else
          puts "#{indent}cloning item: #{pi.resource_item.actual_object}"
          cloned_object = pi.resource_item.actual_object.clone
          cloned_object.accepts_role!(:owner, creator)
          cloned_object.accepts_role!(:creator, creator)
          cloned_object.tag_list = pi.resource_item.actual_object.tag_list
          cloned_object.save
          if pi.resource_item_type == 'ItemCollage'
            pi.resource_item.actual_object.annotations.each do |annotation|
              cloned_annotation = annotation.clone
              cloned_annotation.collage_id = cloned_object.id
              cloned_annotation.save
              #cloned_annotation.tag_list = annotation.tag_list
              #Assigning tag_list doesn't work for annotations
              #So, work directly with taggings array of objects
              annotation.taggings.each do |tagging|
                cloned_tagging = tagging.clone
                cloned_tagging.update_attribute(:taggable_id, cloned_annotation.id)
              end
            end
            puts "#{indent}*cloned annotations"
          end
        end
        cloned_resource_item.actual_object_id = cloned_object.id
        cloned_resource_item.url = cloned_resource_item.url.gsub(/[0-9]+$/, cloned_object.id.to_s)
      end
      cloned_resource_item.save
      cloned_playlist_item.position = pi.position
      cloned_playlist_item.resource_item_id = cloned_resource_item.id
      cloned_playlist_item.playlist_id = cloned_playlist.id
      cloned_playlist_item.save
    end

    cloned_playlist.save

    return cloned_playlist
  end

  desc 'Deep Playlist Copy'
  task(:deep_playlist_copy => :environment) do
    p = Playlist.find(ENV['playlist_id'])
    u = User.find(ENV['user_id'])
    if(p.nil? || u.nil?)
      puts "You must enter a valid playlist and user id to clone."
    end
    result = deep_clone(p, u, "\t")
    puts "Finished cloning! New cloned playlist id: #{result.id}"
  end


  desc 'Clear All Cache'
  task(:clear_all_cache => :environment) do
    system("rm -rf #{RAILS_ROOT}/tmp/cache/*")
    system("rm #{RAILS_ROOT}/public/stylesheets/all.css")
    system("rm #{RAILS_ROOT}/public/javascripts/all.js")
    system("rm -rf #{RAILS_ROOT}/public/collages/*")
    system("rm -rf #{RAILS_ROOT}/public/playlists/*")
  end

  desc 'Test case import'
  task(:import_cases => :environment) do
    # -i --add-xml-decl n --doctype omit --show-body-only true
    TidyFFI::Tidy.default_options.add_xml_decl = false
    TidyFFI::Tidy.default_options.doctype = 'omit'
    TidyFFI::Tidy.default_options.show_body_only = 1
    TidyFFI::Tidy.default_options.output_xhtml = true

    metadata_hash = {}
    FasterCSV.foreach("#{RAILS_ROOT}/tmp/cases/cases.csv", {:headers => :first_row, :header_converters => :symbol}) do |row|
      row_hash = row.to_hash
      metadata_hash[row_hash[:filename]] = row_hash
    end

    Dir.glob("#{RAILS_ROOT}/tmp/cases/*.xml").each do |file|
      c = Case.new()
      basename = Pathname(file).basename.to_s
#      puts file
      doc = Nokogiri::XML.parse(File.open(file))
      unless metadata_hash[basename].blank?
        c.tag_list = metadata_hash[basename][:tags]
      end

#      c.tag_list = 'testimport'
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
      if c.content.blank?
        puts
        puts "Case: #{file} had content problems, using HTML raw"
        puts
        c.content = "#{doc.xpath('//Case/HeaderHtml').text} #{doc.xpath('//Case/CaseHtml').text}"
      end
#      puts
#      puts "Content of #{file}, post-stripping: "
#      puts c.content

#      puts
#      puts

      if c.save
#        puts "Successfully imported: #{file}"
      else 
        puts "FAILED: #{file}"
        puts c.errors.full_messages.join("\n")
        puts
        puts
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

=begin
  desc 'Reassign owner'
  task(:reassign_owner => :environment) do
    # user and playlist is required

    p = Playlist.find(548)

    first_children = p.playlist_items.inject([]) { |arr, pi| arr << pi.resource_item.actual_object; arr }.flatten
    
    second_children = first_children.inject([]) do |barr, i|
      if i.is_a?(Playlist)
        barr << i.playlist_items.inject([]) { |arr, pi| arr << pi.resource_item.actual_object; arr }.flatten
      end
      barr
    end
    
    third_children = second_children.flatten.inject([]) do |barr, i|
      if i.is_a?(Playlist)
        barr << i.playlist_items.inject([]) { |arr, pi| arr << pi.resource_item.actual_object if pi.resource_item.respond_to?(:actual_object); arr }.flatten
      end
      barr
    end
    
    fourth_children = third_children.flatten.inject([]) do |barr, i|
      if i.is_a?(Playlist)
        barr << i.playlist_items.inject([]) { |arr, pi| arr << pi.resource_item.actual_object; arr }.flatten
      end
      barr
    end
    
    to_update = [[p] + first_children + second_children + third_children + fourth_children].flatten
    
    u = User.find_by_login("ProfDavidPost")
    to_update.each do |i|
      if [Playlist,Collage].include?(i.class)
        next if i.owners == [u]
        if i.owners
          i.owners.each { |c| c.has_no_roles_for!(i) }
        end
        u.has_role!(:owner, i) 
      end
      next if i.creators == [u]
      if i.creators
        i.creators.each { |c| c.has_no_roles_for!(i) }
      end
      u.has_role!(:creator, i) 
    end
=end
end
