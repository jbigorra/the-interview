# frozen_string_literal: true

module Apply
  # ATS adapter for Greenhouse job postings.
  #
  # Stub implementation — field extraction and payload building are not yet
  # implemented. Provides +apply_url+ by returning the lead URL directly.
  class GreenhouseAdapter < BaseAdapter
    NOT_IMPLEMENTED = "Greenhouse adapter not yet implemented"

    # Extracts Greenhouse-specific application form fields.
    #
    # @return [Hash] { success: false, response: { error: { message: String } } } (stub)
    def extract_fields
      { success: false, response: { error: { message: NOT_IMPLEMENTED } } }
    end

    # Builds the Greenhouse application form payload from profile data.
    #
    # @return [Hash] { success: false, response: { error: { message: String } } } (stub)
    def build_payload
      { success: false, response: { error: { message: NOT_IMPLEMENTED } } }
    end

    # Returns the Greenhouse application URL.
    #
    # @return [String] the lead's URL
    def apply_url
      lead.url
    end
  end
end
