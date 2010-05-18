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

  def process_content
    doc = Nokogiri::HTML.parse(self.content)
    class_name = 1
    doc.xpath('//*').each do |item|
      puts item.class.name
      if item.is_a?(Nokogiri::XML::Element)
        item['id'] = "n-#{class_name}" 
        class_name += 1
#        if item.children.count == 1 && item.children.first.is_a?(Nokogiri::XML::Text)
          #Leaf node.
#          puts item.inner_html
#          text_content = item.inner_html.split.map{|word|class_name += 1; "<q id='t-#{class_name}'>" + word + '</q>'}.join(' ')
#          puts text_content
#          item.inner_html = text_content
#        end
      end
    end
    self.content = doc.xpath("//html/body/*").to_s
  end

end
