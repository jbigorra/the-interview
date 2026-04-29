# typed: false
# frozen_string_literal: true

module Matching
  # Stage 2 evaluator: scores a lead using Claude Haiku via ruby_llm.
  #
  # Builds a structured prompt from the lead and user's matching criterion,
  # calls the LLM requesting JSON output, and returns a parsed result contract.
  #
  # Pattern 3: Class-only service (all class methods, no instance needed).
  class LlmEvaluator
    MODEL       = "claude-haiku-4-5-20251001"
    MAX_CHARS   = 8_000

    RESPONSE_SCHEMA = {
      type: "object",
      properties: {
        score:          { type: "integer", minimum: 0, maximum: 100 },
        recommendation: { type: "string", enum: %w[apply maybe skip] },
        reasoning:      { type: "string" },
        strengths:      { type: "array", items: { type: "string" } },
        concerns:       { type: "array", items: { type: "string" } }
      },
      required: %w[score recommendation reasoning strengths concerns]
    }.freeze

    # Evaluates a lead against the user's matching criterion using an LLM.
    #
    # @param lead      [Lead]             the lead record with title, company, location, description
    # @param criterion [MatchingCriterion, nil] the user's matching criterion
    # @return [Hash] { success: true,  response: { score: Integer, recommendation: String,
    #                                               reasoning: String, strengths: Array, concerns: Array } }
    #              | { success: false, response: { error: { message: String } } }
    def self.call(lead:, criterion:)
      prompt   = build_prompt(lead, criterion)
      response = chat_with_llm(prompt)
      parsed   = parse_response(response)

      {
        success: true,
        response: {
          score:          parsed[:score],
          recommendation: parsed[:recommendation],
          reasoning:      parsed[:reasoning],
          strengths:      parsed[:strengths] || [],
          concerns:       parsed[:concerns]  || []
        }
      }
    rescue RubyLLM::Error => e
      { success: false, response: { error: { message: "LLM API error: #{e.message}" } } }
    rescue JSON::ParserError => e
      { success: false, response: { error: { message: "Failed to parse LLM response: #{e.message}" } } }
    rescue StandardError => e
      { success: false, response: { error: { message: e.message } } }
    end

    # Builds the evaluation prompt from lead and criterion data.
    #
    # @param lead      [Lead]
    # @param criterion [MatchingCriterion, nil]
    # @return [String] the formatted prompt
    def self.build_prompt(lead, criterion)
      <<~PROMPT
        You are a job matching assistant. Evaluate if this job posting matches the candidate's criteria.

        ## Job Posting
        **Title**: #{lead.title || "Unknown"}
        **Company**: #{lead.company || "Unknown"}
        **Location**: #{lead.location || "Unknown"}
        **Description**: #{truncate(lead.description, MAX_CHARS) || "No description available"}

        ## Candidate Criteria
        **Required Skills**: #{(criterion&.required_keywords || []).join(", ")}
        **Excluded Keywords**: #{(criterion&.excluded_keywords || []).join(", ")}
        **Minimum Salary**: #{criterion&.min_salary || "Not specified"}
        **Preferred Locations**: #{(criterion&.preferred_locations || []).join(", ")}
        **Work Mode**: #{criterion&.work_mode || "Any"}

        Evaluate this job and respond with a JSON object containing:
        - score: integer 0-100 (how well it matches)
        - recommendation: "apply", "maybe", or "skip"
        - reasoning: brief explanation
        - strengths: array of matching factors
        - concerns: array of potential issues

        Respond with ONLY valid JSON. No markdown, no explanations.
      PROMPT
    end

    def self.truncate(text, max_length)
      return text if text.nil? || text.length <= max_length

      "#{text[0...max_length]}..."
    end
    private_class_method :truncate

    def self.chat_with_llm(prompt)
      chat = RubyLLM.chat(model: MODEL)
      chat.with_instructions("You are a job matching assistant. Always respond with valid JSON only.")
      response = chat.with_schema(RESPONSE_SCHEMA).ask(prompt)
      response.content
    end
    private_class_method :chat_with_llm

    def self.parse_response(content)
      json_str = content.to_s.strip
      json_str = json_str.gsub(/```json\s*/i, "").gsub(/```\s*/, "").strip
      JSON.parse(json_str, symbolize_names: true)
    end
    private_class_method :parse_response
  end
end
