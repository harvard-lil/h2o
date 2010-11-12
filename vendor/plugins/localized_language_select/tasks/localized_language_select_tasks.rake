require 'rubygems'
require 'hpricot'
require 'open-uri'

# Rake task for importing language names from Unicode.org's CLDR repository
# (http://www.unicode.org/cldr/data/charts/summary/root.html).
# 
# It parses a HTML file from Unicode.org for given locale and saves the 
# Rails' I18n hash in the plugin +locale+ directory
# 
# Don't forget to restart the application when you add new locale to load it into Rails!
# 
# == Example
#   rake import:language_select locale=de
# 
# The code is deliberately procedural and simple, so it's easily
# understandable by beginners as an introduction to Rake tasks power.
# See http://github.com/joshmh/cldr/tree/master/converter.rb for much more robust solution

namespace :import do

  desc "Import language codes and names for various languages from the Unicode.org CLDR archive. Depends on Hpricot gem."
  task :language_select do
    
    # TODO : Implement locale import chooser from CLDR root via Highline
    
    # Setup variables
    locale = ENV['locale']
    unless locale
      puts "\n[!] Usage: rake import:language_select locale=de\n\n"
      exit 0
    end

    # ----- Get the CLDR HTML     --------------------------------------------------
    begin
      puts "... getting the HTML file for locale '#{locale}'"
      doc = Hpricot( open("http://www.unicode.org/cldr/data/charts/summary/#{locale}.html") )
    rescue => e
      puts "[!] Invalid locale name '#{locale}'! Not found in CLDR (#{e})"
      exit 0
    end

    require 'ruby-debug'

    # ----- Parse the HTML with Hpricot     ----------------------------------------
    puts "... parsing the HTML file"
    languages = []
    doc.search("//tr").each do |row|
      if row.search("td[@class='n']") && 
         row.search("td[@class='n']").inner_html =~ /^nameslanguage$/ && 
         row.search("td[@class='g']").inner_html =~ /^[a-z]{2,3}(?:_([A-Z][a-z]{3}))?(?:_([A-Z]{2}))?$/
        code   = row.search("td[@class='g']").inner_text
        code.sub!('_','-')
        #debugger if code =~ /-/
        name   = row.search("td[@class='v']").first.inner_text
        languages << { :code => code.to_sym, :name => name.to_s }
        print " ... #{name}"
      end
    end


    # ----- Prepare the output format     ------------------------------------------
    output =<<HEAD
{
  :#{locale} => {
    :languages => {
HEAD
    languages.each do |language|
      output << "      #{language[:code].inspect} => \"#{language[:name]}\",\n"
    end
    output <<<<TAIL
    } 
  }
}
TAIL

    
    # ----- Write the parsed values into file      ---------------------------------
    puts "\n... writing the output"
    filename = File.join(File.dirname(__FILE__), '..', 'locale', "#{locale}.rb")
    filename += '.NEW' if File.exists?(filename) # Append 'NEW' if file exists
    File.open(filename, 'w+') { |f| f << output }
    puts "\n---\nWritten values for the '#{locale}' into file: #{filename}\n"
    # ------------------------------------------------------------------------------
  end

end
