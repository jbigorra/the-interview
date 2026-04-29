# typed: false
# frozen_string_literal: true

RubyLLM.configure do |config|
  config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil)
  config.openai_api_key    = ENV.fetch("OPENAI_API_KEY", nil)
end
