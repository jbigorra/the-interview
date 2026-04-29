# typed: false
# frozen_string_literal: true

module Apply
  # ATS adapter for Greenhouse job postings.
  #
  # Returns structured field definitions for the Greenhouse application form.
  # Each field includes label, type, required flag, and the pre-filled value
  # sourced from the user's profile. Payload uses separate symbol keys for
  # standard fields and merges string-keyed common answers on top.
  class GreenhouseAdapter < BaseAdapter
    STANDARD_FIELDS = [
      { id: "first_name",   label: "First Name",    type: "text",     required: true },
      { id: "last_name",    label: "Last Name",     type: "text",     required: true },
      { id: "email",        label: "Email",         type: "email",    required: true },
      { id: "phone",        label: "Phone",         type: "tel",      required: false },
      { id: "resume",       label: "Resume",        type: "file",     required: true },
      { id: "cover_letter", label: "Cover Letter",  type: "textarea", required: false }
    ].freeze

    # Extracts Greenhouse-specific application form fields with pre-filled values.
    #
    # @return [Hash] { success: true, response: { fields: Array<Hash>, apply_url: String } }
    def extract_fields
      fields = STANDARD_FIELDS.map do |field|
        field.merge(value: standard_fields[field[:id].to_sym])
      end

      { success: true, response: { fields: fields, apply_url: apply_url } }
    end

    # Builds the Greenhouse application form payload from profile data.
    # Merges standard profile fields with any stored common answers.
    #
    # @return [Hash] { success: true, response: { payload: Hash, apply_url: String } }
    def build_payload
      payload = {
        first_name:   profile.personal_info&.dig("first_name"),
        last_name:    profile.personal_info&.dig("last_name"),
        email:        profile.email,
        phone:        profile.personal_info&.dig("phone"),
        cover_letter: profile.cover_letter_template
      }.merge(common_answers).compact

      { success: true, response: { payload: payload, apply_url: apply_url } }
    end

    # Returns the Greenhouse application URL.
    #
    # @return [String] the lead's URL
    def apply_url
      lead.url
    end
  end
end
