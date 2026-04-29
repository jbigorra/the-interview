# typed: false
# frozen_string_literal: true

# Stage 1 matching job: evaluates a lead against keyword-based criteria.
#
# Passing leads are moved to :reviewed stage (pending LLM evaluation).
# Failing leads are moved to :skipped with the rejection reason stored
# in match_reasoning. Leads without any matching criterion auto-pass to :reviewed.
# Leads that have already been evaluated (evaluated_at present) are skipped.
class Stage1MatchingJob < ApplicationJob
  queue_as :matching

  retry_on StandardError, wait: :exponentially_longer, attempts: 2

  # @param lead [Lead] the lead record to evaluate
  # @return [void]
  def perform(lead)
    if lead.evaluated_at.present?
      Rails.logger.info("Stage1MatchingJob: lead #{lead.id} already evaluated — skipping")
      return
    end

    criterion = lead.profile.matching_criterion

    unless criterion
      Rails.logger.info("Stage1MatchingJob: no matching criteria for profile #{lead.profile_id} — auto-passing lead #{lead.id}")
      lead.update!(stage: :reviewed)
      return
    end

    result = Matching::KeywordEvaluator.call(lead: lead, criterion: criterion)

    unless result[:success]
      Rails.logger.error("Stage1MatchingJob: KeywordEvaluator failed for lead #{lead.id}: #{result[:response]}")
      return
    end

    if result[:response][:passed]
      lead.update!(stage: :reviewed)
      Rails.logger.info("Stage1MatchingJob: lead #{lead.id} passed Stage 1 — moved to reviewed")
    else
      lead.update!(stage: :skipped, match_reasoning: result[:response][:reason])
      Rails.logger.info("Stage1MatchingJob: lead #{lead.id} failed Stage 1 — #{result[:response][:reason]}")
    end
  end
end
