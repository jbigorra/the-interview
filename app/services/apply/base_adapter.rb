# typed: false
# frozen_string_literal: true

module Apply
  # Abstract base adapter for ATS-specific application submission.
  #
  # Concrete adapters (GreenhouseAdapter, LeverAdapter, AshbyAdapter) inherit
  # from this class and implement the three abstract methods below.
  class BaseAdapter
    NOT_IMPLEMENTED = "Subclasses must implement this method"

    # @param lead [Lead] the lead record containing ATS URL and metadata
    # @param profile [Profile] the user's profile with resume and common answers
    def initialize(lead:, profile:)
      @lead = lead
      @profile = profile
    end

    # Extracts ATS-specific form fields from the job page.
    #
    # @return [Hash] { success: Boolean, response: Hash }
    # @raise [NotImplementedError] if not overridden by a subclass
    def extract_fields
      raise NotImplementedError, NOT_IMPLEMENTED
    end

    # Builds the form payload to submit to the ATS.
    #
    # @return [Hash] { success: Boolean, response: Hash }
    # @raise [NotImplementedError] if not overridden by a subclass
    def build_payload
      raise NotImplementedError, NOT_IMPLEMENTED
    end

    # Returns the direct application URL for this ATS posting.
    #
    # @return [String] the URL where the application form is located
    # @raise [NotImplementedError] if not overridden by a subclass
    def apply_url
      raise NotImplementedError, NOT_IMPLEMENTED
    end

    private

    attr_reader :lead, :profile
  end
end
