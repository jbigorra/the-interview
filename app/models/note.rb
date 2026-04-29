# typed: false

class Note < ApplicationRecord
  belongs_to :lead

  validates :body, presence: true
  validates :author, presence: true

  default_scope { order(created_at: :desc) }
end
