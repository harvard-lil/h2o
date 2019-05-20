require 'capapi'

Capapi.api_base = ENV["CAPAPI_BASE"] || "https://api.case.law"
Capapi.api_key = ENV["CAPAPI_KEY"]
Capapi.max_network_retries = ENV["CAPAPI_MAX_RETRIES"] || 3
