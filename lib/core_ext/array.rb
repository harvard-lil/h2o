class Array

  def to_tsv
    res = ''
    self.each do |element|
      FasterCSV.generate(res, :col_sep => "\t") do |csv|
        csv << element.to_tsv
      end
    end
    res
  end
end
