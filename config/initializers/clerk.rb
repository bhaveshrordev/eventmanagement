# config/initializers/clerk.rb
Clerk.configure do |c|
  # Prefer env var; you can paste the key temporarily for local dev but avoid committing keys.
  c.secret_key = ENV.fetch('CLERK_SECRET_KEY', nil)
  c.publishable_key = ENV.fetch('CLERK_PUBLISHABLE_KEY', nil)
  # Optional: configure logger if you want debug-level Clerk logs
  c.logger = Rails.logger
end
