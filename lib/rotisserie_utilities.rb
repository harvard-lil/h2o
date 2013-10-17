module RotisserieUtilities
  def date_to_round(ititial_date, target_date, round_length)
    date_advance = ititial_date.to_datetime
    round = 0

    until target_date.to_datetime < date_advance do
      date_advance = date_advance.advance(:days => round_length)
      round += 1
    end

    return round
  end
end
