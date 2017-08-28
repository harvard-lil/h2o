Content::Casebook.order(:id).all.each do |c|
  puts "Exporting casebook #{c.id}, '#{c.title}'..."
  html = ApplicationController.render(
    :template => 'content/casebooks/export',
    :layout => 'export',
    :assigns => { content: c, casebook: c }
  )
  html.gsub! '\\', '\\\\\\'
  Htmltoword::Document.create_and_save(html, Rails.root.join("tmp/export/casebook-#{c.id}-#{c.title.gsub '/', '-'}.docx"))
  puts "Exported."
end
