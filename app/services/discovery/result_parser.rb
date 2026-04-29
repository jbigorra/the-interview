# typed: false
# frozen_string_literal: true

module Discovery
  # Parses raw SerpApi organic results into structured lead attribute hashes.
  #
  # Accepts an array of organic_results from SerpApi (symbolized keys) and
  # normalizes each entry into a hash suitable for creating Lead records.
  #
  # Pattern 3: Class-only service (stateless, no instance state needed).
  class ResultParser
    # Parses raw SerpApi results into structured lead attribute hashes.
    #
    # @param raw_results [Array<Hash>] organic_results array from SerpApi (symbolized keys)
    # @param profile [Profile] the profile context for lead creation (unused in parsing but kept for interface consistency)
    # @return [Hash] { success: true, response: { leads: Array<Hash>, count: Integer } }
    #   on success, or { success: false, response: { error: { message: String } } } on failure
    def self.call(raw_results, profile: nil) # rubocop:disable Lint/UnusedMethodArgument
      leads_data = raw_results.filter_map { |result| parse_result(result) }
      { success: true, response: { leads: leads_data, count: leads_data.size } }
    rescue => e
      { success: false, response: { error: { message: e.message } } }
    end

    # Parses a single SerpApi organic result into a lead attribute hash.
    #
    # @param result [Hash] a single organic result entry (symbolized keys from SerpApi)
    # @return [Hash, nil] lead attribute hash or nil if the result has no URL
    def self.parse_result(result)
      url = result[:link] || result[:url]
      return nil unless url

      title_str = result[:title].to_s
      snippet = result[:snippet].to_s

      {
        title: extract_job_title(title_str),
        company: extract_company(title_str, snippet),
        location: extract_location(snippet),
        url: url,
        description: snippet,
        raw_payload: result
      }
    end

    # Extracts the company name from a SerpApi result title or snippet.
    #
    # SerpApi titles commonly follow "Company - Job Title" or "Company | Job Title" patterns.
    #
    # @param title [String] the result title
    # @param snippet [String] the result snippet
    # @return [String] extracted company name or "Unknown"
    def self.extract_company(title, snippet) # rubocop:disable Lint/UnusedMethodArgument
      if title.include?(" - ")
        title.split(" - ").first.strip
      elsif title.include?(" | ")
        title.split(" | ").first.strip
      else
        "Unknown"
      end
    end

    # Extracts the job title portion from a SerpApi result title.
    #
    # @param title [String] the result title
    # @return [String] extracted job title
    def self.extract_job_title(title)
      if title.include?(" - ")
        title.split(" - ").last.strip
      elsif title.include?(" | ")
        title.split(" | ").last.strip
      else
        title
      end
    end

    # Extracts a location hint from the result snippet.
    #
    # Full extraction occurs when the ATS page is visited.
    # Returns nil as a placeholder for the heuristic phase.
    #
    # @param snippet [String] the result snippet
    # @return [nil] always nil in this heuristic phase
    def self.extract_location(snippet) # rubocop:disable Lint/UnusedMethodArgument
      nil
    end
  end
end
