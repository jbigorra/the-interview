# frozen_string_literal: true

module Discovery
  # Parses raw SerpApi JSON results into structured lead data.
  #
  # Currently a stub — result parsing is not yet implemented.
  # When implemented, this service will extract:
  #   - title, company, location, url, description snippet
  # and return an array of normalized lead attribute hashes.
  #
  # Pattern 3: Class-only service.
  class ResultParser
    NOT_IMPLEMENTED = "Not yet implemented — requires SerpApi result format"

    # Parses raw SerpApi results into structured lead attribute hashes.
    #
    # @param raw_results [Hash] raw JSON response from SerpApi
    # @return [Hash] { success: false, response: { error: { message: String } } } (stub)
    def self.call(raw_results) # rubocop:disable Lint/UnusedMethodArgument
      # TODO: Parse SerpApi JSON results into structured lead data
      # Extract: title, company, location, url, description snippet
      { success: false, response: { error: { message: NOT_IMPLEMENTED } } }
    end
  end
end
