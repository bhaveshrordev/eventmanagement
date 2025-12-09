class Event < ApplicationRecord
  validates :external_id, presence: true, uniqueness: true
  validates :title, presence: true

  scope :published, -> { where(published_state: 'published') }
  scope :upcoming, -> { where('starts_at >= ?', Time.current).order(starts_at: :asc) }
 
  def organiser_name
    organiser && (organiser['name'] || organiser['title'])
  end

  def city
    location && location['city']
  end

  def minimum_price_amount
    return nil unless minimum_price
    minimum_price['amount_in_cents'] || minimum_price['amount']
  end

  # Return a sanitized description for rendering (or truncation)
  def short_description(length = 250)
    ActionView::Base.full_sanitizer.sanitize(description.to_s).truncate(length)
  end
end
