# spec/models/event_spec.rb
require 'rails_helper'

RSpec.describe Event, type: :model do
  describe 'validations' do
    subject { build(:event) }

    it { is_expected.to validate_presence_of(:external_id) }
    it { is_expected.to validate_uniqueness_of(:external_id) }

    it { is_expected.to validate_presence_of(:title) }
  end

  describe 'associations' do
    it { is_expected.to have_one(:event_vote) }
    it { is_expected.to have_one(:event_vote_tally) }
  end

  describe 'scopes' do
    describe '.upcoming_first' do
      it 'sorts future starts_at first, then past, then nil last' do
        future = create(:event, starts_at: 2.days.from_now)
        past   = create(:event, starts_at: 2.days.ago)
        nil_start = create(:event, starts_at: nil)

        results = Event.upcoming_first.limit(3).to_a
        # Expect first -> future, second -> past, third -> nil
        expect(results.map(&:id)).to eq([future.id, past.id, nil_start.id])
      end
    end
  end

  describe '#short_description' do
    it 'sanitizes html and truncates' do
      long_html = "<p>Hello <strong>World</strong></p>" + "a" * 300
      e = build(:event, description: long_html)
      short = e.short_description(50)
      expect(short).to be_a(String)
      expect(short.length).to be <= 50
      expect(short).not_to include('<p>')
      expect(short).to include('Hello')
    end
  end

  describe '#organiser_name and #city and #minimum_price_amount' do
    it 'reads organiser name and city and price' do
      e = build(:event,
                organiser: { 'name' => 'Org' },
                location: { 'city' => 'Mumbai' },
                minimum_price: { 'amount_in_cents' => 1250 })
      expect(e.organiser_name).to eq('Org')
      expect(e.city).to eq('Mumbai')
      expect(e.minimum_price_amount).to eq(1250)
    end
  end
end
