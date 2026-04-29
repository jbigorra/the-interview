# frozen_string_literal: true

require "vcr"
require "webmock/rspec"

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.ignore_localhost = true
  config.filter_sensitive_data("<SERPAPI_API_KEY>") { ENV["SERPAPI_API_KEY"] }
  config.default_cassette_options = {
    record: :new_episodes,
    allow_playback_repeats: true
  }
end
