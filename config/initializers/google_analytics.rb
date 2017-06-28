if Rails.env == 'production' || Rails.env == 'staging'
  GOOGLE_ANALYTICS_CODE = nil
elsif Rails.env == 'test'
    GOOGLE_ANALYTICS_CODE = nil
else
  GOOGLE_ANALYTICS_CODE = 'UA-223559-16'
end
