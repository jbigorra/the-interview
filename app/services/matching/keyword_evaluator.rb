# typed: false
# frozen_string_literal: true

module Matching
  # Stage 1 filter: evaluates whether a lead passes basic keyword criteria.
  #
  # Checks excluded keywords first (early rejection), then required keywords.
  # If no criterion is provided, the lead passes by default.
  #
  # Pattern 3: Class-only service (stateless).
  class KeywordEvaluator
    NO_CRITERIA = "No criteria set"
    EXCLUDED_FOUND = "Excluded keywords found"
    MISSING_REQUIRED = "Missing required keywords"

    # Evaluates a lead against keyword-based matching criteria.
    #
    # @param lead [Lead] the lead record with title and description attributes
    # @param criterion [MatchingCriterion, nil] the matching criterion for the profile;
    #   pass nil to skip evaluation and auto-pass
    # @return [Hash] { success: true, response: { passed: Boolean, reason: String } }
    #   Always returns success: true — use response[:passed] to determine the outcome
    def self.call(lead:, criterion:)
      return { success: true, response: { passed: true, reason: NO_CRITERIA } } unless criterion

      description = (lead.description || "").downcase
      title = (lead.title || "").downcase
      full_text = "#{title} #{description}"

      excluded = (criterion.excluded_keywords || []).map(&:downcase)
      matched_excluded = excluded.select { |kw| full_text.include?(kw) }
      if matched_excluded.any?
        reason = "#{EXCLUDED_FOUND}: #{matched_excluded.join(', ')}"
        return { success: true, response: { passed: false, reason: reason } }
      end

      required = (criterion.required_keywords || []).map(&:downcase)
      if required.any?
        missing = required.reject { |kw| full_text.include?(kw) }
        if missing.any?
          reason = "#{MISSING_REQUIRED}: #{missing.join(', ')}"
          return { success: true, response: { passed: false, reason: reason } }
        end
      end

      { success: true, response: { passed: true, reason: "All keyword checks passed" } }
    end
  end
end
