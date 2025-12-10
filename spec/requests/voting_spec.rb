# spec/requests/voting_spec.rb
require 'rails_helper'

RSpec.describe "Voting", type: :request do
  let!(:event) { create(:event) }

  # helper to stub clerk methods on controller instances
  def stub_clerk(signed_in:, user_id: nil)
    allow_any_instance_of(ApplicationController).to receive(:clerk_signed_in?).and_return(signed_in)
    allow_any_instance_of(ApplicationController).to receive(:current_clerk_user_id).and_return(user_id)
  end

  describe "POST /events/:id/vote" do
    context "when user is not signed in" do
      before do
        stub_clerk(signed_in: false)
        allow(Rails.configuration.event_store).to receive(:publish).and_return(nil)
      end

      it "does not allow voting and redirects to sign in (or returns unauthorized)" do
        post vote_event_path(event, vote: 'up')

        expect(response).to have_http_status(:found).or have_http_status(:unauthorized)
        expect(Rails.configuration.event_store).not_to have_received(:publish)
      end
    end

    context "when user is signed in" do
      let(:fake_user_id) { "user_test_123" }

      before do
        stub_clerk(signed_in: true, user_id: fake_user_id)

        # capture published event into @last_published for assertions
        @last_published = nil
        allow(Rails.configuration.event_store).to receive(:publish) do |published_event|
          @last_published = published_event
          # return value not important for controller flow
          nil
        end
      end

      it "publishes an upvote event and responds (redirects back)" do
        post vote_event_path(event, vote: 'up')

        expect(Rails.configuration.event_store).to have_received(:publish).once
        expect(@last_published).to be_present

        if @last_published.respond_to?(:data)
          payload = @last_published.data
        else
          payload = @last_published.try(:[], 'data') || @last_published
        end

        expect(payload).to be_present
        expect(payload['event_id'] || payload[:event_id]).to eq(event.id)
        expect(payload['user_id'] || payload[:user_id]).to eq(fake_user_id)
        expect(%w[up down]).to include((payload['vote'] || payload[:vote]).to_s)

        expect(response).to have_http_status(:found).or have_http_status(:ok)
      end

      it "rejects invalid vote param and does not publish" do
        post vote_event_path(event, vote: 'invalid_choice')

        expect(Rails.configuration.event_store).not_to have_received(:publish)
        expect(response).to have_http_status(:bad_request).or have_http_status(:found).or have_http_status(:ok)
      end
    end
  end
end
