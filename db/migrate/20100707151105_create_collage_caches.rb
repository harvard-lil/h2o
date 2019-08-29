class CreateCollageCaches < ActiveRecord::Migration
  def self.up
    add_column :collages, :word_count, :integer
    add_index :collages, :word_count

    if connection.adapter_name.downcase == 'postgresql'
      add_column :collages, :indexable_content, :string, :limit => 5.megabytes
    else
      add_column :collages, :indexable_content, :string, :limit => 5.megabytes
    end

    Collage.all.each do |c|
      doc = HTMLUtils.parse(c.content)
      word_count = 0
      indexable_content = []
      doc.xpath('//tt').each do |n|
        word_count += 1
        indexable_content << n.text.strip 
      end
      c.word_count = word_count
      c.indexable_content = indexable_content.join(' ')
      c.save
    end

  end

  def self.down
    remove_column :collages, :word_count, :indexable_content
  end
end
