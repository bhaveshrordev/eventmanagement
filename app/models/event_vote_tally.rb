# app/models/event_vote_tally.rb
class EventVoteTally < ApplicationRecord
  belongs_to :event
end
