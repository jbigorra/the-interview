# typed: false
# frozen_string_literal: true

# Stage 2 matching job: evaluates a lead using the LLM-based evaluator.
#
# Leads above or within 20 points of the criterion threshold are moved to :reviewed.
# Leads more than 20 points below the threshold are moved to :skipped.
# Leads without a matching criterion auto-pass to :reviewed.
# Leads that already have a match_score are skipped (idempotent guard).
# RubyLLM::Error is discarded — the lead is moved to :reviewed with a failure note.
# Other errors trigger exponential-backoff retries (3 attempts).
class Stage2MatchingJob < ApplicationJob
  queue_as :matching

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  discard_on RubyLLM::Error do |job, error|
    lead = job.arguments.first
    Rails.logger.error("Stage2MatchingJob: RubyLLM::Error for lead #{lead.id}: #{error.message}")
    lead.update!(stage: :reviewed, match_reasoning: "LLM evaluation failed: #{error.message}")
  end

  # @param lead [Lead] the lead record to evaluate
  # @return [void]
  def perform(lead)
    if lead.match_score.present?
      Rails.logger.info("Stage2MatchingJob: lead #{lead.id} already has LLM score — skipping")
      return
    end

    criterion = lead.profile.matching_criterion

    unless criterion
      Rails.logger.info("Stage2MatchingJob: no matching criteria for profile #{lead.profile_id} — auto-passing lead #{lead.id}")
      lead.update!(stage: :reviewed)
      return
    end

    result = Matching::LlmEvaluator.call(lead: lead, criterion: criterion)

    unless result[:success]
      error_message = result[:response][:error][:message]
      Rails.logger.error("Stage2MatchingJob: LlmEvaluator failed for lead #{lead.id}: #{error_message}")
      raise error_message
    end

    response = result[:response]
    lead.update!(
      match_score:          response[:score],
      match_recommendation: response[:recommendation],
      match_reasoning:      response[:reasoning],
      evaluated_at:         Time.current
    )

    apply_threshold_decision(lead, response[:score], criterion)
  end

  private

  def apply_threshold_decision(lead, score, criterion)
    threshold = criterion.llm_threshold || 70

    if score >= threshold
      lead.update!(stage: :reviewed)
      Rails.logger.info("Stage2MatchingJob: lead #{lead.id} scored #{score} (threshold: #{threshold}) — passed Stage 2")
    elsif score >= (threshold - 20)
      lead.update!(stage: :reviewed)
      Rails.logger.info("Stage2MatchingJob: lead #{lead.id} scored #{score} (threshold: #{threshold}) — borderline, manual review recommended")
    else
      lead.update!(stage: :skipped)
      Rails.logger.info("Stage2MatchingJob: lead #{lead.id} scored #{score} (threshold: #{threshold}) — skipped")
    end
  end
end
