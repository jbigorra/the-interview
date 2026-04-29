# typed: false
# frozen_string_literal: true

# Stage 1 matching job: evaluates a lead against keyword-based criteria.
#
# Before evaluation, attempts ATS enrichment when the lead description is
# blank or too short (< 200 chars) and the ATS type is a known provider.
# Enrichment failures are logged and swallowed — the job continues with
# whatever data is already on the lead.
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

    enrich_from_ats(lead)

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
      Stage2MatchingJob.perform_later(lead)
    else
      lead.update!(stage: :skipped, match_reasoning: result[:response][:reason])
      Rails.logger.info("Stage1MatchingJob: lead #{lead.id} failed Stage 1 — #{result[:response][:reason]}")
    end
  end

  private

  # Fetches full job details from the ATS API and updates the lead in-place.
  #
  # Enrichment is skipped when:
  # - the description is already long enough (>= 200 chars)
  # - the ats_type is not a known provider (greenhouse, lever, ashby)
  #
  # Any HTTP or parsing error is rescued and logged; the job continues with
  # the existing lead data rather than failing.
  #
  # @param lead [Lead] the lead to enrich
  # @return [void]
  def enrich_from_ats(lead)
    return if lead.description.present? && lead.description.length >= 200
    return unless Discovery::AtsFetcher::SUPPORTED_ATS.include?(lead.ats_type)

    result = Discovery::AtsFetcher.call(url: lead.url, ats_type: lead.ats_type)
    return unless result[:success]

    data = result[:response]
    updates = {}
    updates[:title]       = data[:title]       if data[:title].present?       && lead.title.blank?
    updates[:company]     = data[:company]     if data[:company].present?     && lead.company.blank?
    updates[:location]    = data[:location]    if data[:location].present?    && lead.location.blank?
    updates[:description] = data[:description] if data[:description].present?
    updates[:raw_payload] = data[:raw_payload] if data[:raw_payload].present?

    lead.update!(updates) if updates.any?
  rescue => e
    Rails.logger.warn("Stage1MatchingJob: ATS enrichment failed for lead #{lead.id}: #{e.message}")
  end
end
