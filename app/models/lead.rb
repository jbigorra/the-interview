# typed: false

class Lead < ApplicationRecord
  belongs_to :profile
  has_one :application, dependent: :destroy
  has_many :notes, dependent: :destroy
  has_many :lead_events, dependent: :destroy

  # NOTE: `new` is reserved by ActiveRecord — use `fresh` for "new/unreviewed" leads on the board.
  enum :stage, {
    fresh:        0,
    reviewed:     1,
    applied:      2,
    interviewing: 3,
    offered:      4,
    rejected:     5,
    skipped:      6
  }, default: :fresh, validate: true

  enum :match_recommendation, {
    apply: "apply",
    maybe: "maybe",
    skip:  "skip"
  }, validate: { allow_nil: true }

  validates :url, presence: true
  validates :fingerprint, presence: true, uniqueness: { scope: :profile_id }

  scope :by_stage_position, -> { order(stage_position: :asc) }

  before_validation :generate_fingerprint, on: :create

  # Moves the lead to a new stage and records a LeadEvent.
  # @param new_stage [Symbol, String] the target stage
  # @return [Lead] self after update
  def move_to!(new_stage)
    old_stage_value = self.class.stages[stage]
    update!(stage: new_stage)
    new_stage_value = self.class.stages[stage]
    lead_events.create!(from_stage: old_stage_value, to_stage: new_stage_value, trigger: "manual")
    self
  end

  private

  def generate_fingerprint
    self.fingerprint = Digest::SHA256.hexdigest(url) if url.present? && fingerprint.blank?
  end
end
