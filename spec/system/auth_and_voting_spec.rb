# spec/system/auth_and_voting_spec.rb
require "rails_helper"

RSpec.describe "Authentication & voting (browser)", type: :system do
  # Use rack_test for speed. Change to selenium_chrome_headless for JS interactions.
  before do
    driven_by :rack_test
  end

  let!(:event) { create(:event, title: "Concert", external_id: "ext_1") }

  # Helpers to stub controller-level Clerk behaviour for system tests.
  def stub_clerk_signed_out
    allow_any_instance_of(ApplicationController).to receive(:clerk_signed_in?).and_return(false)
    allow_any_instance_of(ApplicationController).to receive(:current_clerk_user_id).and_return(nil)
    clerk_double = double("clerk", user: nil, session_claims: nil, session_token: nil)
    allow_any_instance_of(ApplicationController).to receive(:clerk_responds_to?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:clerk).and_return(clerk_double)
  end

  def stub_clerk_signed_in(user_id: "user_sys_1", email: "sys@test.example")
    allow_any_instance_of(ApplicationController).to receive(:clerk_signed_in?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_clerk_user_id).and_return(user_id)

    email_addr = double("EmailAddress", email: email)
    user_obj = double("User", id: user_id, email_addresses: [email_addr])
    clerk_double = double("clerk",
                         user: user_obj,
                         session_claims: { "sub" => user_id },
                         session_token: "session_token_abc")
    allow_any_instance_of(ApplicationController).to receive(:clerk_responds_to?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:clerk).and_return(clerk_double)
  end

  # Build an XPath-safe literal for arbitrary strings (handles single quotes).
  def xpath_literal(str)
    return "''" if str.nil? || str == ""
    if str.include?("'")
      parts = str.split("'").map { |p| "'#{p}'" } # each part single-quoted
      # join parts with , "'", to construct concat('a', "'", 'b', ...)
      "concat(#{parts.join(%q{, "'", })})"
    else
      "'#{str}'"
    end
  end

  # pick the first card matching the event title to avoid ambiguous matches
  def card_for(event)
    xpath = "//h5[text()=#{xpath_literal(event.title)}]/ancestor::div[contains(@class,'card')]"
    first(:xpath, xpath)
  end

  before do
    # Clean relevant tables for deterministic tests
    EventVote.delete_all if defined?(EventVote)
    EventVoteTally.delete_all if defined?(EventVoteTally)
    if ActiveRecord::Base.connection.table_exists?("event_store_events")
      ActiveRecord::Base.connection.execute("DELETE FROM event_store_events")
    end
    if ActiveRecord::Base.connection.table_exists?("event_store_events_in_streams")
      ActiveRecord::Base.connection.execute("DELETE FROM event_store_events_in_streams")
    end
  end

  it "shows login button to anonymous users and prevents voting" do
    stub_clerk_signed_out

    visit root_path

    card = card_for(event)
    expect(card).to be_truthy, "expected to find a card for event #{event.title}"

    within(card) do
      expect(page).to have_button("Login to vote").or have_link("Login to vote")
    end

    # clicking the Login to vote should lead to sign_in path (app behaviour may vary)
    within(card) do
      click_on("Login to vote") rescue nil
    end
    expect(page.current_path).to include("sign_in").or satisfy { |p| page.current_url.include?("sign-in") }
  end

  it "allows a signed-in user to vote and updates the UI/tally" do
    stub_clerk_signed_in(user_id: "user_sys_42", email: "sysuser@example.com")

    visit root_path

    card = card_for(event)
    expect(card).to be_truthy, "expected to find a card for event #{event.title}"

    within(card) do
      # click the upvote button (emoji + count). use first(:button, ...) to be safe.
      btn = first(:button, text: /Like/)
      expect(btn).to be_present
      btn.click
    end

    # Reload page to see updated tally (projector or controller must update DB on publish in tests)
    visit root_path

    card = card_for(event)
    within(card) do
      expect(page).to have_button(/Like\s*1/).or have_content("Like 1")
    end
  end

  it "supports sign out flow and then prevents voting again" do
    stub_clerk_signed_in(user_id: "u_out", email: "out@example.com")
    visit root_path
    expect(page).to have_link("Manage Account").or have_link("Manage Account")

    # Simulate sign out
    stub_clerk_signed_out
    visit root_path

    card = card_for(event)
    within(card) do
      expect(page).to have_button("Login to vote").or have_link("Login to vote")
    end
  end
end
