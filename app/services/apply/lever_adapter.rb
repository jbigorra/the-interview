# typed: false
# frozen_string_literal: true

module Apply
  # ATS adapter for Lever job postings.
  #
  # Lever uses a combined "name" field rather than separate first/last name.
  # The pre-filled value joins the profile's first and last name automatically.
  # Payload uses symbol keys for standard fields and merges string-keyed
  # common answers on top.
  class LeverAdapter < BaseAdapter
    STANDARD_FIELDS = [
      { id: "name",  label: "Full Name",    type: "text",     required: true },
      { id: "email", label: "Email",        type: "email",    required: true },
      { id: "phone", label: "Phone",        type: "tel",      required: false },
      { id: "resume", label: "Resume/CV",   type: "file",     required: true },
      { id: "cover", label: "Cover Letter", type: "textarea", required: false }
    ].freeze

    # Maps Lever field ids to standard_fields symbol keys where they differ.
    LEVER_FIELD_MAP = {
      "name"  => :name,
      "cover" => :cover_letter
    }.freeze

    # Extracts Lever-specific application form fields with pre-filled values.
    # Combines first_name and last_name into a single "name" field.
    #
    # @return [Hash] { success: true, response: { fields: Array<Hash>, apply_url: String } }
    def extract_fields
      fields = STANDARD_FIELDS.map do |field|
        value = if field[:id] == "name"
          full_name
        else
          standard_key = LEVER_FIELD_MAP.fetch(field[:id], field[:id].to_sym)
          standard_fields[standard_key]
        end
        field.merge(value: value)
      end

      { success: true, response: { fields: fields, apply_url: apply_url } }
    end

    # Builds the Lever application form payload from profile data.
    # Merges standard profile fields with any stored common answers.
    #
    # @return [Hash] { success: true, response: { payload: Hash, apply_url: String } }
    def build_payload
      payload = {
        name:  full_name.presence,
        email: profile.email,
        phone: profile.personal_info&.dig("phone"),
        cover: profile.cover_letter_template
      }.merge(common_answers).compact

      { success: true, response: { payload: payload, apply_url: apply_url } }
    end

    # Returns the Lever application URL.
    #
    # @return [String] the lead's URL
    def apply_url
      lead.url
    end

    private

    def full_name
      "#{profile.personal_info&.dig('first_name')} #{profile.personal_info&.dig('last_name')}".strip
    end
  end
end
