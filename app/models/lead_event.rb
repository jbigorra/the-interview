# typed: false

class LeadEvent < ApplicationRecord
  belongs_to :lead

  validates :to_stage, presence: true
  validates :trigger, presence: true

  default_scope { order(created_at: :desc) }
end
