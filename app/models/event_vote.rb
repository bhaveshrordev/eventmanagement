# app/models/event_vote.rb
class EventVote < ApplicationRecord
  belongs_to :event
  validates :user_id, presence: true
  validates :vote, inclusion: { in: %w[up down] }
end
