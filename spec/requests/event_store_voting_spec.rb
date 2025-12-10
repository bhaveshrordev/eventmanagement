# spec/requests/event_store_voting_spec.rb
require 'rails_helper'

RSpec.describe "Rails Event Store — Voting flow", type: :request do
  let!(:event) { create(:event) }

  # simple helper to count events written to event_store_events table for a given event type
  def event_store_count_for(event_type)
    sql = ActiveRecord::Base.sanitize_sql_array(
      ["SELECT COUNT(*) FROM event_store_events WHERE event_type = ?", event_type]
    )
    ActiveRecord::Base.connection.select_value(sql).to_i
  end

  # helper to stub clerk auth in controller
  def stub_clerk(signed_in:, user_id: nil, email: nil)
    allow_any_instance_of(ApplicationController).to receive(:clerk_signed_in?).and_return(signed_in)
    allow_any_instance_of(ApplicationController).to receive(:current_clerk_user_id).and_return(user_id)
    # minimal clerk double used by some controller code paths
    clerk_double = double(
      user: double(email_addresses: [double(email: email)]),
      session_claims: nil,
      session_token: nil
    )
    allow_any_instance_of(ApplicationController).to receive(:clerk_responds_to?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:clerk).and_return(clerk_double)
  end

  before do
    # clean slate before each example
    ActiveRecord::Base.connection.execute("DELETE FROM event_store_events_in_streams")
    ActiveRecord::Base.connection.execute("DELETE FROM event_store_events")
    EventVoteTally.delete_all
    EventVote.delete_all
  end

  context "when user is signed in" do
    it "creates an EventUpvoted row and updates tally" do
      stub_clerk(signed_in: true, user_id: "user_1", email: "u1@example.com")

      expect(event_store_count_for("EventUpvoted")).to eq(0)
      expect(EventVoteTally.where(event_id: event.id).count).to eq(0)

      post vote_event_path(event, vote: 'up')

      expect(response).to have_http_status(:found).or have_http_status(:ok)
      expect(event_store_count_for("EventUpvoted")).to eq(1)

      tally = EventVoteTally.find_by(event_id: event.id)
      expect(tally).to be_present
      expect(tally.upvotes_count).to eq(1)
      expect(tally.downvotes_count).to eq(0)
    end

    it "creates EventDownvoted and updates tally accordingly" do
      stub_clerk(signed_in: true, user_id: "user_2", email: "u2@example.com")
      expect(event_store_count_for("EventDownvoted")).to eq(0)

      post vote_event_path(event, vote: 'down')

      expect(response).to have_http_status(:found).or have_http_status(:ok)
      expect(event_store_count_for("EventDownvoted")).to eq(1)

      tally = EventVoteTally.find_by(event_id: event.id)
      expect(tally).to be_present
      expect(tally.downvotes_count).to eq(1)
      expect(tally.upvotes_count).to eq(0)
    end

    it "multiple votes from different users create multiple event rows and aggregated tally" do
      # Use different users for each vote so projector will count them as distinct votes.
      stub_clerk(signed_in: true, user_id: "user_a", email: "a@example.com")
      post vote_event_path(event, vote: 'up')

      stub_clerk(signed_in: true, user_id: "user_b", email: "b@example.com")
      post vote_event_path(event, vote: 'up')

      stub_clerk(signed_in: true, user_id: "user_c", email: "c@example.com")
      post vote_event_path(event, vote: 'down')

      # ensure rows persisted
      expect(event_store_count_for("EventUpvoted")).to eq(2)
      expect(event_store_count_for("EventDownvoted")).to eq(1)

      tally = EventVoteTally.find_by(event_id: event.id)
      expect(tally).to be_present
      expect(tally.upvotes_count).to eq(2)
      expect(tally.downvotes_count).to eq(1)
    end
  end

  context "when user is not signed in" do
    before do
      stub_clerk(signed_in: false)
    end

    it "does not write any event_store events and redirects to sign_in" do
      expect {
        post vote_event_path(event, vote: 'up')
      }.not_to change { event_store_count_for("EventUpvoted") }

      expect(response).to have_http_status(:found).or have_http_status(:unauthorized)
    end
  end
end
