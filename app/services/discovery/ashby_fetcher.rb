# typed: false
# frozen_string_literal: true

require "net/http"
require "json"

module Discovery
  # Fetches a job listing from the Ashby public posting API and normalizes the payload.
  #
  # Ashby job board URL format: https://jobs.ashbyhq.com/{company}/{job_id}
  # Ashby API format: https://api.ashbyhq.com/posting-api/job-board/{company}
  #   The API returns ALL job postings for the board; we filter by job_id.
  #
  # Pattern 3: Class-only service (stateless, no instance state needed).
  class AshbyFetcher
    API_BASE = "https://api.ashbyhq.com/posting-api/job-board"

    # Fetches an Ashby job listing and returns a normalized payload.
    #
    # @param url [String] Ashby job listing URL
    # @return [Hash] { success: true, response: { title:, company:, location:, description:, raw_payload: } }
    #   on success, or { success: false, response: { error: { message: String } } } on failure
    def self.call(url)
      uri = URI.parse(url)
      path_parts = uri.path.split("/").reject(&:empty?)
      # Expected format: /{company}/{job_id}
      company = path_parts[0]
      job_id  = path_parts.last

      api_url  = "#{API_BASE}/#{company}"
      raw_body = Net::HTTP.get(URI.parse(api_url))
      data     = JSON.parse(raw_body)

      job = find_job(data, job_id)
      unless job
        return { success: false, response: { error: { message: "Job #{job_id} not found in Ashby board" } } }
      end

      {
        success: true,
        response: {
          title:       job["title"],
          company:     job.dig("organization", "name") || company.humanize,
          location:    job["locationName"] || job["location"],
          description: job["descriptionPlain"] || job["description"],
          raw_payload: job
        }
      }
    rescue JSON::ParserError => e
      { success: false, response: { error: { message: "Failed to parse Ashby API response: #{e.message}" } } }
    rescue => e
      { success: false, response: { error: { message: "Ashby API error: #{e.message}" } } }
    end

    # Finds a job posting by id within the Ashby board response.
    #
    # Ashby nests postings under different keys depending on API version:
    #   - data["jobPostings"]  (flat list, common in newer responses)
    #   - data["jobBoard"]["jobPostings"]  (nested under jobBoard)
    #
    # @param data [Hash] parsed Ashby API JSON
    # @param job_id [String] the job posting id to find
    # @return [Hash, nil] the job posting hash or nil if not found
    def self.find_job(data, job_id)
      postings = data["jobPostings"] ||
                 data.dig("jobBoard", "jobPostings") ||
                 []
      postings.find { |j| j["id"] == job_id }
    end

    private_class_method :find_job
  end
end
