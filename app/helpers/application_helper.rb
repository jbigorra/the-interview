module ApplicationHelper
  def safe_external_url(url)
    return nil unless url.present? && url.starts_with?("http")
    url
  end
end
