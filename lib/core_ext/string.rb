class String
  def clean_layer
    #Note: Implemented in multiple areas in our javascript/ruby
    self
      .gsub(/ /, 'whitespace')
      .gsub(/\./, 'specialsymbol')
      .gsub(/'/, 'apostrophe')
      .gsub(/\)/, 'rightparen')
      .gsub(/\(/, 'leftparen')
      .gsub(/,/, 'c0mma')
      .gsub(/\&/, 'amp3r')
  end
end
