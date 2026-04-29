# typed: false
class SearchQuery < ApplicationRecord
  belongs_to :profile

  validates :title, presence: true
  validates :portal, presence: true

  scope :recently_run, -> { where(last_run_at: 24.hours.ago..) }

  # @return [Boolean] true if this query was run within the last 24 hours
  def recently_run?
    last_run_at.present? && last_run_at > 24.hours.ago
  end

  # @return [String] the full Google dork query string
  def to_google_query
    parts = [ "site:#{portal}" ]
    parts << "\"#{title}\"" if title.present?
    parts << additional_filters if additional_filters.present?
    parts.join(" ")
  end
end
