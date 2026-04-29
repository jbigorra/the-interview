# typed: false
# frozen_string_literal: true

module Apply
  # Routes an application request to the correct ATS adapter based on the
  # lead's +ats_type+ attribute.
  #
  # Returns an instantiated adapter and the apply URL on success, or an error
  # with the lead's fallback URL when the ATS is not supported.
  #
  # Pattern 3: Class-only service (orchestrator with no instance state).
  class Orchestrator
    UNSUPPORTED_ATS = "Unsupported ATS"

    ADAPTER_MAP = {
      "greenhouse" => Apply::GreenhouseAdapter,
      "lever"      => Apply::LeverAdapter,
      "ashby"      => Apply::AshbyAdapter
    }.freeze

    # Resolves and instantiates the ATS adapter for the given lead.
    #
    # @param lead [Lead] the lead record with +ats_type+ and +url+ attributes
    # @param profile [Profile] the user's profile passed to the adapter
    # @return [Hash] { success: true, response: { adapter: BaseAdapter, apply_url: String } }
    #   on success, or { success: false, response: { error: { message: String }, apply_url: String } }
    #   when the ATS is not supported
    # @raise [StandardError] any unexpected error is rescued and returned as failure
    def self.call(lead:, profile:)
      adapter_class = ADAPTER_MAP[lead.ats_type]

      unless adapter_class
        return {
          success: false,
          response: { error: { message: "#{UNSUPPORTED_ATS}: #{lead.ats_type}" }, apply_url: lead.url }
        }
      end

      adapter = adapter_class.new(lead: lead, profile: profile)
      { success: true, response: { adapter: adapter, apply_url: adapter.apply_url } }
    rescue StandardError => e
      Rails.logger.error("Apply::Orchestrator error: #{e.message}")
      { success: false, response: { error: { message: e.message } } }
    end
  end
end
