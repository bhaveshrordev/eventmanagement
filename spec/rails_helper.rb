# spec/rails_helper.rb
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'

# --- Shoulda Matchers ---
require 'shoulda/matchers'

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# Optional: FactoryBot shorthand
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  # Use transactional fixtures (default)
  config.use_transactional_fixtures = true

  # infer spec types from file location
  config.infer_spec_type_from_file_location!

  # filter Rails backtrace
  config.filter_rails_from_backtrace!
end
