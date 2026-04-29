# frozen_string_literal: true

module Discovery
  # Executes SerpApi queries built from a SearchQuery record.
  #
  # Currently a stub — SerpApi integration is not yet implemented.
  # When implemented, this service will:
  #   1. Build a Google dork query from the SearchQuery record
  #   2. Call SerpApi with the constructed query string
  #   3. Return structured raw results for ResultParser to consume
  #
  # Pattern 3: Class-only service.
  class QueryExecutor
    NOT_IMPLEMENTED = "Not yet implemented — requires SerpApi integration"

    # Executes a SerpApi query from the given SearchQuery record.
    #
    # @param search_query [SearchQuery] the query record with portal, title, and filters
    # @return [Hash] { success: false, response: { error: { message: String } } } (stub)
    def self.call(search_query) # rubocop:disable Lint/UnusedMethodArgument
      # TODO: Implement SerpApi integration
      # 1. Build Google dork query from SearchQuery record
      # 2. Call SerpApi
      # 3. Return parsed results
      { success: false, response: { error: { message: NOT_IMPLEMENTED } } }
    end
  end
end
