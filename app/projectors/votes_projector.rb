# app/projectors/votes_projector.rb
class VotesProjector
  def call(event)
    case event
    when EventUpvoted
      apply_upvote(event)
    when EventDownvoted
      apply_downvote(event)
    end
  end

  private

  def apply_upvote(res_event)
    data = res_event.data
    event_id = data['event_id']
    user_id = data['user_id']
    vote = data['vote'] # 'up' ideally

    ActiveRecord::Base.transaction do
      ev = EventVote.lock.find_by(event_id: event_id, user_id: user_id)

      if ev.nil?
        # create new vote
        EventVote.create!(event_id: event_id, user_id: user_id, vote: 'up', metadata: data)
        tally = EventVoteTally.lock.find_or_initialize_by(event_id: event_id)
        tally.upvotes_count = (tally.upvotes_count || 0) + 1
        tally.save!
      elsif ev.vote == 'down'
        # change vote from down -> up
        ev.update!(vote: 'up', metadata: data)
        tally = EventVoteTally.lock.find_or_initialize_by(event_id: event_id)
        tally.downvotes_count = (tally.downvotes_count || 0) - 1
        tally.upvotes_count   = (tally.upvotes_count   || 0) + 1
        tally.save!
      else
        # already upvoted; ignore (idempotent)
      end
    end
  end

  def apply_downvote(res_event)
    data = res_event.data
    event_id = data['event_id']
    user_id = data['user_id']
    vote = data['vote']

    ActiveRecord::Base.transaction do
      ev = EventVote.lock.find_by(event_id: event_id, user_id: user_id)

      if ev.nil?
        EventVote.create!(event_id: event_id, user_id: user_id, vote: 'down', metadata: data)
        tally = EventVoteTally.lock.find_or_initialize_by(event_id: event_id)
        tally.downvotes_count = (tally.downvotes_count || 0) + 1
        tally.save!
      elsif ev.vote == 'up'
        ev.update!(vote: 'down', metadata: data)
        tally = EventVoteTally.lock.find_or_initialize_by(event_id: event_id)
        tally.upvotes_count   = (tally.upvotes_count   || 0) - 1
        tally.downvotes_count = (tally.downvotes_count || 0) + 1
        tally.save!
      else
        # already downvoted; ignore
      end
    end
  end
end
