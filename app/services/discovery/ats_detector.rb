# frozen_string_literal: true

module Discovery
  # Detects which ATS platform a job URL belongs to by matching the host
  # against a known mapping of ATS domains.
  #
  # Pattern 3: Class-only service (stateless, no instance state needed).
  class AtsDetector
    UNKNOWN_ATS = "Unknown ATS"

    ATS_MAPPING = {
      "jobs.lever.co"      => "lever",
      "boards.greenhouse.io" => "greenhouse",
      "jobs.ashbyhq.com"   => "ashby",
      "jobs.jobvite.com"   => "jobvite",
      "myworkdayjobs.com"  => "workday",
      "careers.jobscore.com" => "jobscore",
      "ats.comparably.com" => "comparably"
    }.freeze

    # Detects the ATS type from the given job URL.
    #
    # @param url [String] the job listing URL to inspect
    # @return [Hash] { success: true, response: { ats_type: String, url: String } }
    #   on success, or { success: false, response: { error: { message: String }, url: String } }
    #   when the ATS is not recognized
    def self.call(url)
      uri = URI.parse(url)
      host = uri.host || ""
      ats_type = ATS_MAPPING.find { |domain, _| host.include?(domain) }&.last

      unless ats_type
        return { success: false, response: { error: { message: UNKNOWN_ATS }, url: url } }
      end

      { success: true, response: { ats_type: ats_type, url: url } }
    rescue URI::InvalidURIError => e
      { success: false, response: { error: { message: e.message }, url: url } }
    end
  end
end
