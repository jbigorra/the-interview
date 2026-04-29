# typed: false
class MatchingCriterion < ApplicationRecord
  belongs_to :profile

  validates :work_mode, inclusion: { in: %w[remote hybrid onsite], allow_nil: true }
  validates :llm_threshold, numericality: { only_integer: true, in: 0..100, allow_nil: true }
end
