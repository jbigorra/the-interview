# typed: false
# frozen_string_literal: true

require "net/http"
require "json"

module Discovery
  # Fetches a job listing from the Lever public API and normalizes the payload.
  #
  # Lever job board URL format: https://jobs.lever.co/{company}/{job_id}
  # Lever API format: https://api.lever.co/v0/postings/{company}/{job_id}
  #
  # Pattern 3: Class-only service (stateless, no instance state needed).
  class LeverFetcher
    API_BASE = "https://api.lever.co/v0/postings"

    # Fetches a Lever job listing and returns a normalized payload.
    #
    # @param url [String] Lever job listing URL
    # @return [Hash] { success: true, response: { title:, company:, location:, description:, raw_payload: } }
    #   on success, or { success: false, response: { error: { message: String } } } on failure
    def self.call(url)
      uri = URI.parse(url)
      path_parts = uri.path.split("/").reject(&:empty?)
      # Expected format: /{company}/{job_id}
      company = path_parts[0]
      job_id  = path_parts.last

      api_url  = "#{API_BASE}/#{company}/#{job_id}"
      raw_body = Net::HTTP.get(URI.parse(api_url))
      data     = JSON.parse(raw_body)

      {
        success: true,
        response: {
          title:       data["text"],
          company:     data.dig("categories", "team") || company.humanize,
          location:    extract_location(data),
          description: data["descriptionPlain"] || data["description"] || data["text"],
          raw_payload: data
        }
      }
    rescue JSON::ParserError => e
      { success: false, response: { error: { message: "Failed to parse Lever API response: #{e.message}" } } }
    rescue => e
      { success: false, response: { error: { message: "Lever API error: #{e.message}" } } }
    end

    # Extracts location from Lever API data, trying several known paths.
    #
    # @param data [Hash] parsed Lever API JSON
    # @return [String, nil]
    def self.extract_location(data)
      data.dig("categories", "location") ||
        data["workplaceType"] ||
        data.dig("locations", 0)
    end

    private_class_method :extract_location
  end
end
