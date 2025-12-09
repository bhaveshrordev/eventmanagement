class Event < ApplicationRecord
  validates :external_id, presence: true, uniqueness: true
  validates :title, presence: true
end
