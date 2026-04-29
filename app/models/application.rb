# typed: false
class Application < ApplicationRecord
  belongs_to :lead

  enum :status, { draft: "draft", submitted: "submitted", error: "error" }, validate: true

  validates :ats_type, presence: true
  validates :status, presence: true

  def submitted?
    submitted_at.present?
  end
end
