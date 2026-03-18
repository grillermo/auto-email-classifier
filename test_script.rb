require 'googleauth'
puts Signet::OAuth2::Client.instance_method(:fetch_access_token!).source_location
