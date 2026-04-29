# typed: false
# frozen_string_literal: true

module Apply
  # ATS adapter for Ashby job postings.
  #
  # Ashby uses camelCase field identifiers (firstName, lastName, coverLetter).
  # Payload keys follow Ashby's API naming convention using camelCase symbols.
  # Common answers are merged on top with their original string keys.
  class AshbyAdapter < BaseAdapter
    STANDARD_FIELDS = [
      { id: "firstName",   label: "First Name",    type: "text",     required: true },
      { id: "lastName",    label: "Last Name",     type: "text",     required: true },
      { id: "email",       label: "Email",         type: "email",    required: true },
      { id: "phone",       label: "Phone",         type: "tel",      required: false },
      { id: "resume",      label: "Resume",        type: "file",     required: true },
      { id: "coverLetter", label: "Cover Letter",  type: "textarea", required: false }
    ].freeze

    # Maps Ashby camelCase field ids to standard_fields symbol keys.
    ASHBY_FIELD_MAP = {
      "firstName"   => :first_name,
      "lastName"    => :last_name,
      "email"       => :email,
      "phone"       => :phone,
      "resume"      => :resume,
      "coverLetter" => :cover_letter
    }.freeze

    # Extracts Ashby-specific application form fields with pre-filled values.
    #
    # @return [Hash] { success: true, response: { fields: Array<Hash>, apply_url: String } }
    def extract_fields
      fields = STANDARD_FIELDS.map do |field|
        standard_key = ASHBY_FIELD_MAP[field[:id]]
        field.merge(value: standard_fields[standard_key])
      end

      { success: true, response: { fields: fields, apply_url: apply_url } }
    end

    # Builds the Ashby application form payload from profile data.
    # Uses camelCase keys matching Ashby's API convention.
    # Merges standard profile fields with any stored common answers.
    #
    # @return [Hash] { success: true, response: { payload: Hash, apply_url: String } }
    def build_payload
      payload = {
        firstName:   profile.personal_info&.dig("first_name"),
        lastName:    profile.personal_info&.dig("last_name"),
        email:       profile.email,
        phone:       profile.personal_info&.dig("phone"),
        coverLetter: profile.cover_letter_template
      }.merge(common_answers).compact

      { success: true, response: { payload: payload, apply_url: apply_url } }
    end

    # Returns the Ashby application URL.
    #
    # @return [String] the lead's URL
    def apply_url
      lead.url
    end
  end
end
