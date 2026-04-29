# frozen_string_literal: true

module Discovery
  # Executes Google search queries via SerpApi and returns raw organic results.
  #
  # Builds a Google dork query from a SearchQuery record and calls SerpApi.
  # Updates the SearchQuery's `last_run_at` and `run_count` on success.
  #
  # Pattern 3: Class-only service (stateless, no instance state needed).
  class QueryExecutor
    GOOGLE_ENGINE = "google"
    MAX_RESULTS = 100

    # Executes a SerpApi search for the given SearchQuery record.
    #
    # @param search_query [SearchQuery] the query record with portal, title, and filters
    # @return [Hash] { success: true, response: { results: Array, query: String, count: Integer } }
    #   on success, or { success: false, response: { error: { message: String }, query: String } }
    #   on failure
    def self.call(search_query)
      query = build_query(search_query)
      results = execute_serpapi(query)
      search_query.update!(last_run_at: Time.current, run_count: search_query.run_count + 1)
      { success: true, response: { results: results, query: query, count: results.size } }
    rescue SerpApi::SerpApiError => e
      { success: false, response: { error: { message: "SerpApi error: #{e.message}" }, query: query } }
    rescue => e
      { success: false, response: { error: { message: e.message }, query: query } }
    end

    # Builds the Google dork query string from a SearchQuery record.
    #
    # @param search_query [SearchQuery] the query record
    # @return [String] the Google dork query string
    def self.build_query(search_query)
      parts = []
      parts << "site:#{search_query.portal}"
      parts << "\"#{search_query.title}\""
      parts << "\"remote\""
      parts << search_query.additional_filters if search_query.additional_filters.present?
      parts.join(" ")
    end

    private_class_method def self.execute_serpapi(query)
      client = SerpApi::Client.new(
        api_key: ENV.fetch("SERPAPI_API_KEY", nil),
        engine: GOOGLE_ENGINE,
        persistent: false
      )
      results = client.search(q: query, num: MAX_RESULTS)
      results[:organic_results] || []
    end
  end
end
