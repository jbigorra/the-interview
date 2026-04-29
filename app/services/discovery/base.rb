# typed: false
# frozen_string_literal: true

module Discovery
  # Base class providing shared behavior for all Discovery services.
  #
  # All Discovery services follow the {success:, response:} contract.
  # Subclasses call +self.call+ as the public entry point.
  class Base
    NOT_IMPLEMENTED = "Subclass must implement .call"

    # @return [Hash] { success: false, response: { error: { message: String } } }
    def self.call(*)
      { success: false, response: { error: { message: NOT_IMPLEMENTED } } }
    end
  end
end
