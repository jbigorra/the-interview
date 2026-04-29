# typed: false
# frozen_string_literal: true

require "net/http"
require "json"

module Discovery
  # Fetches a job listing from the Greenhouse public API and normalizes the payload.
  #
  # Greenhouse job board URL format: https://boards.greenhouse.io/{company}/jobs/{job_id}
  # Greenhouse API format: https://boards-api.greenhouse.io/v1/boards/{company}/jobs/{job_id}
  #
  # Pattern 3: Class-only service (stateless, no instance state needed).
  class GreenhouseFetcher
    API_BASE = "https://boards-api.greenhouse.io/v1/boards"

    # Fetches a Greenhouse job listing and returns a normalized payload.
    #
    # @param url [String] Greenhouse job listing URL
    # @return [Hash] { success: true, response: { title:, company:, location:, description:, raw_payload: } }
    #   on success, or { success: false, response: { error: { message: String } } } on failure
    def self.call(url)
      uri = URI.parse(url)
      path_parts = uri.path.split("/").reject(&:empty?)
      # Expected format: /{company}/jobs/{job_id}
      company = path_parts[0]
      job_id  = path_parts.last

      api_url  = "#{API_BASE}/#{company}/jobs/#{job_id}"
      raw_body = Net::HTTP.get(URI.parse(api_url))
      data     = JSON.parse(raw_body)

      {
        success: true,
        response: {
          title:       data["title"],
          company:     data.dig("departments", 0, "name") || company.humanize,
          location:    extract_location(data),
          description: data["content"] || data["description"],
          raw_payload: data
        }
      }
    rescue JSON::ParserError => e
      { success: false, response: { error: { message: "Failed to parse Greenhouse API response: #{e.message}" } } }
    rescue => e
      { success: false, response: { error: { message: "Greenhouse API error: #{e.message}" } } }
    end

    # Extracts location from Greenhouse API data, trying several known paths.
    #
    # @param data [Hash] parsed Greenhouse API JSON
    # @return [String, nil]
    def self.extract_location(data)
      data.dig("locations", 0, "name") ||
        data.dig("location", "name") ||
        data["location"]
    rescue
      nil
    end

    private_class_method :extract_location
  end
end
