require 'capapi'

Capapi.api_base = ENV["CAPAPI_BASE"] || "https://capapi.org/api"
Capapi.api_key = ENV["CAPAPI_KEY"]
Capapi.max_network_retries = ENV["CAPAPI_MAX_RETRIES"] || 3
