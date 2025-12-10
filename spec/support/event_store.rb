RSpec.configure do |config|
  config.before(:each) do
    # Use a fresh Rails Event Store client per example
    Rails.configuration.event_store = RailsEventStore::Client.new
  end
end
