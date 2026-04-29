# frozen_string_literal: true

require "rails_helper"

RSpec.describe FullDiscoveryJob, type: :job do
  describe "#perform" do
    context "when no profile exists" do
      it "does not enqueue any DiscoveryJobs" do
        expect { described_class.new.perform }
          .not_to have_enqueued_job(DiscoveryJob)
      end
    end

    context "when a profile exists" do
      let(:profile) { create(:profile) }

      context "when all queries are in cooldown" do
        before do
          create(:search_query, profile: profile, last_run_at: 1.hour.ago)
          create(:search_query, profile: profile, last_run_at: 2.hours.ago)
        end

        it "does not enqueue any DiscoveryJobs" do
          expect { described_class.new.perform(profile) }
            .not_to have_enqueued_job(DiscoveryJob)
        end
      end

      context "when some queries are in cooldown and some are not" do
        let!(:recent_query) { create(:search_query, profile: profile, last_run_at: 30.minutes.ago) }
        let!(:ready_query) { create(:search_query, profile: profile, last_run_at: nil) }

        it "enqueues DiscoveryJob only for non-cooldown queries" do
          expect { described_class.new.perform(profile) }
            .to have_enqueued_job(DiscoveryJob).exactly(1).times
        end

        it "enqueues the job for the ready query" do
          described_class.new.perform(profile)
          expect(DiscoveryJob).to have_been_enqueued.with(ready_query)
        end
      end

      context "when no queries have been run yet" do
        let!(:query_a) { create(:search_query, profile: profile, last_run_at: nil) }
        let!(:query_b) { create(:search_query, profile: profile, last_run_at: nil) }

        it "enqueues a DiscoveryJob for each query" do
          expect { described_class.new.perform(profile) }
            .to have_enqueued_job(DiscoveryJob).exactly(2).times
        end
      end

      context "when called without an explicit profile argument" do
        it "uses Profile.first" do
          profile # create the profile so Profile.first returns it
          create(:search_query, profile: profile, last_run_at: nil)

          expect { described_class.new.perform }
            .to have_enqueued_job(DiscoveryJob).exactly(1).times
        end
      end
    end
  end
end
