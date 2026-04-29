# typed: false
# frozen_string_literal: true

# Processes a single SearchQuery: executes SerpApi, parses results,
# deduplicates by fingerprint, and enqueues Stage1MatchingJob for new leads.
#
# Rate-limited to 1 concurrent run per profile via Solid Queue semaphores.
class DiscoveryJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1,
    key: ->(search_query) { "discovery_#{search_query.profile_id}" },
    duration: 1.minute

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  # @param search_query [SearchQuery] the query record to execute
  # @return [void]
  def perform(search_query)
    return if search_query.recently_run?

    result = Discovery::QueryExecutor.call(search_query)
    raise "QueryExecutor failed: #{result[:response]}" unless result[:success]

    parsed = Discovery::ResultParser.call(result[:response][:results], profile: search_query.profile)
    raise "ResultParser failed: #{parsed[:response]}" unless parsed[:success]

    created = 0
    skipped = 0

    parsed[:response][:leads].each do |lead_data|
      fingerprint = Digest::SHA256.hexdigest(lead_data[:url])

      if Lead.exists?(profile: search_query.profile, fingerprint: fingerprint)
        skipped += 1
        next
      end

      ats_result = Discovery::AtsDetector.call(lead_data[:url])
      ats_type = ats_result[:success] ? ats_result[:response][:ats_type] : "unknown"

      lead = Lead.create!(
        profile: search_query.profile,
        title: lead_data[:title],
        company: lead_data[:company],
        location: lead_data[:location],
        url: lead_data[:url],
        ats_type: ats_type,
        description: lead_data[:description],
        raw_payload: lead_data[:raw_payload],
        stage: :fresh
      )

      Stage1MatchingJob.perform_later(lead)
      created += 1
    end

    Rails.logger.info("DiscoveryJob complete for #{search_query.title}: #{created} created, #{skipped} duplicates")
  end
end
