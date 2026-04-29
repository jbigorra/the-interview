# frozen_string_literal: true

module Matching
  # Stage 2 evaluator: scores a lead using an LLM (Claude Haiku via ruby_llm).
  #
  # Currently a stub — LLM integration is not yet implemented.
  # When implemented, this service will:
  #   1. Build a structured prompt with job description + user criteria
  #   2. Call the LLM requesting JSON output
  #   3. Parse the response: { score: 0-100, recommendation: "apply/maybe/skip", reasoning: "..." }
  #
  # Pattern 3: Class-only service.
  class LlmEvaluator
    NOT_IMPLEMENTED = "Not yet implemented — requires ruby_llm + API key"

    # Evaluates a lead against the user's profile criteria using an LLM.
    #
    # @param lead [Lead] the lead record with title and description attributes
    # @param criterion [MatchingCriterion] the matching criterion with llm_threshold
    # @return [Hash] { success: false, response: { error: { message: String } } } (stub)
    def self.call(lead:, criterion:) # rubocop:disable Lint/UnusedMethodArgument
      # TODO: Implement ruby_llm integration with Claude Haiku
      # 1. Build prompt with job description + user criteria
      # 2. Call LLM with structured JSON output
      # 3. Parse response: { score: 0-100, recommendation: "apply/maybe/skip", reasoning: "..." }
      { success: false, response: { error: { message: NOT_IMPLEMENTED } } }
    end
  end
end
