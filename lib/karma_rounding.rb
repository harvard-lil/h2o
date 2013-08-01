module KarmaRounding

  def karma_display
    case karma
    when nil
      ''
    when 0
      ''
    when 1..9
      '1+'
    when 10..999
      "#{(karma.to_i/10)*10}+"
    else
      "#{(karma.to_i/100)*100}+"
    end
  end

end
