class VotesProjector
  def call(event)
    case event
    when EventUpvoted
      apply_vote(event, to: "up")
    when EventDownvoted
      apply_vote(event, to: "down")
    end
  end

  private

  def apply_vote(res_event, to:)
    data     = res_event.data
    event_id = data["event_id"]
    user_id  = data["user_id"]

    ActiveRecord::Base.transaction do
      vote = EventVote.lock.find_by(event_id: event_id, user_id: user_id)

      if vote.nil?
        create_vote(event_id, user_id, to, data)
        update_tally(event_id, from: nil, to: to)
        return
      end

      return if vote.vote == to

      from = vote.vote

      vote.update!(vote: to, metadata: data)
      update_tally(event_id, from: from, to: to)
    end
  end

  def create_vote(event_id, user_id, vote, metadata)
    EventVote.create!(
      event_id: event_id,
      user_id: user_id,
      vote: vote,
      metadata: metadata
    )
  end

  def update_tally(event_id, from:, to:)
    tally = EventVoteTally.lock.find_or_initialize_by(event_id: event_id)

    decrement(tally, from) if from
    increment(tally, to)

    tally.save!
  end

  def increment(tally, vote)
    case vote
    when "up"
      tally.upvotes_count = tally.upvotes_count.to_i + 1
    when "down"
      tally.downvotes_count = tally.downvotes_count.to_i + 1
    end
  end

  def decrement(tally, vote)
    case vote
    when "up"
      tally.upvotes_count = tally.upvotes_count.to_i - 1
    when "down"
      tally.downvotes_count = tally.downvotes_count.to_i - 1
    end
  end
end
