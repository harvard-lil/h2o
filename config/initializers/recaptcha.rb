Recaptcha.configure do |config|
  if Rails.env == 'production'
    config.public_key  = '6LeUtO8SAAAAAIyHgb-Q8NDrt45wAHiVKnCmq6RP'
    config.private_key = '6LeUtO8SAAAAAIJPjt3JHKCZAROHh1aKRPiJHsjV'
  else
    config.public_key  = '6Ld5Z_MSAAAAABy7Cec8OFHFU2Mx512Q70Ni53MH'
    config.private_key = '6Ld5Z_MSAAAAAHEAyHWK221u1cF-P4GlrIr8cp0c'
    # config.proxy = 'http://myproxy.com.au:8080'
  end
end
