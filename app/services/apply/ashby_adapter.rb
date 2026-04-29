# typed: false
# frozen_string_literal: true

module Apply
  # ATS adapter for Ashby job postings.
  #
  # MVP implementation: returns standard profile fields for extraction and
  # payload building. Full form-scraping logic is deferred to T16.
  class AshbyAdapter < BaseAdapter
    # Extracts Ashby-specific application form fields from the profile.
    #
    # @return [Hash] { success: true, response: { fields: Hash, apply_url: String } }
    def extract_fields
      { success: true, response: { fields: standard_fields, apply_url: apply_url } }
    end

    # Builds the Ashby application form payload from profile data.
    # Merges standard fields with any stored common answers.
    #
    # @return [Hash] { success: true, response: { payload: Hash } }
    def build_payload
      payload = standard_fields.merge(common_answers)
      { success: true, response: { payload: payload } }
    end

    # Returns the Ashby application URL.
    #
    # @return [String] the lead's URL
    def apply_url
      lead.url
    end
  end
end
