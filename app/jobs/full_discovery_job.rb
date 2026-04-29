# typed: false
# frozen_string_literal: true

# Enqueues a DiscoveryJob for every non-cooldown SearchQuery belonging to a profile.
#
# Designed to be invoked by Solid Queue's recurring schedule (every 6h in production,
# every 1h in development) or manually from the console.
class FullDiscoveryJob < ApplicationJob
  queue_as :default

  # @param profile [Profile, nil] the profile whose queries should run;
  #   falls back to Profile.first when nil
  # @return [void]
  def perform(profile = nil)
    profile ||= Profile.first

    unless profile
      Rails.logger.warn("FullDiscoveryJob: no profile found — skipping")
      return
    end

    queries = profile.search_queries.reject(&:recently_run?)

    if queries.empty?
      Rails.logger.info("FullDiscoveryJob: no queries to run (all in cooldown)")
      return
    end

    queries.each { |query| DiscoveryJob.perform_later(query) }

    Rails.logger.info("FullDiscoveryJob: enqueued #{queries.size} discovery jobs for profile #{profile.id}")
  end
end
