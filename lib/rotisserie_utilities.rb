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

  def role_users(object_id, object_class, object_role)
    Role.first(:conditions => {:name => object_role, :authorizable_type => object_class.to_s, :authorizable_id => object_id}).users
  end
    
end
