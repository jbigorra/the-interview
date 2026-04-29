# typed: false
# frozen_string_literal: true

module Discovery
  # Routes an ATS job URL to the correct fetcher adapter and normalizes the payload.
  #
  # Supported ATS types: greenhouse, lever, ashby.
  # Returns a normalized {success:, response:} hash with title, company, location,
  # description, and raw_payload on success.
  #
  # Pattern 3: Class-only service (stateless, no instance state needed).
  class AtsFetcher
    SUPPORTED_ATS = %w[greenhouse lever ashby].freeze

    # Fetches and normalizes a job listing from the given URL using the detected ATS adapter.
    #
    # @param url [String] the ATS job listing URL
    # @param ats_type [String] the ATS platform identifier (e.g. "greenhouse", "lever", "ashby")
    # @return [Hash] { success: true, response: { title:, company:, location:, description:, raw_payload: } }
    #   on success, or { success: false, response: { error: { message: String } } } on failure
    def self.call(url:, ats_type:)
      adapter = case ats_type
      when "greenhouse" then GreenhouseFetcher
      when "lever"      then LeverFetcher
      when "ashby"      then AshbyFetcher
      else
                  return { success: false, response: { error: { message: "Unsupported ATS type: #{ats_type}" } } }
      end

      adapter.call(url)
    rescue => e
      { success: false, response: { error: { message: e.message } } }
    end
  end
end
