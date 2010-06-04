class Case < ActiveRecord::Base
  has_many :case_citations
  has_many :case_docket_numbers
  belongs_to :case_jurisdiction
  has_many :annotations, :through => :collages
  has_many :collages, :as => :annotatable, :dependent => :destroy

  before_create :process_content

  validates_presence_of   :short_name, :full_name, :content
  validates_length_of     :short_name,      :in => 1..150
  validates_length_of     :full_name,       :in => 1..500
  validates_length_of     :party_header,    :in => 1..(10.kilobytes), :allow_blank => true
  validates_length_of     :lawyer_header,   :in => 1..(2.kilobytes), :allow_blank => true
  validates_length_of     :header_html,     :in => 1..(15.kilobytes), :allow_blank => true
  validates_length_of     :content,         :in => 1..(5.megabytes), :allow_blank => true

  private

  def process_content
    content_to_parse = self.content.gsub(/<br>/,'<br />')
    doc = Nokogiri::HTML.parse(content_to_parse)
    class_name = 1
    doc.css('p,div,li,td,th,h1,h2,h3,h4,h5,h6,center,address,blockquote,dl,ol,ul,pre,dd,dt').each do |item|
  #    puts item.class.name
      if item.is_a?(Nokogiri::XML::Element) 
        item['id'] = "n#{class_name}" 
        puts item.name
        class_name += 1
        if item.children.count > 0 
          #Leaf node.
#          puts item.inner_html
          text_content = item.inner_html.split.map{|word|class_name += 1; "<tt id='t#{class_name}'>" + word + '</tt>'}.join(' ')
#          puts text_content
          item.inner_html = text_content
        end
      end
    end
    self.content = doc.xpath("//html/body/*").to_s
  end

  def process_node(node)

  end

end
