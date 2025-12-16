# app/controllers/home_controller.rb
class HomeController < ApplicationController
  before_action :set_event, only: %i[vote]

  def index
    @pagy, @events = pagy(:offset, Event.upcoming_first.includes(:event_vote_tally))

    begin
      try_process_pending_vote
    rescue => e
      Rails.logger.error("[HomeController#index] try_process_pending_vote failed: #{e.class} #{e.message}")
    end
  end

  # POST /events/:id/vote or POST /vote with id param
  def vote
    vote_type = params[:vote].to_s
    unless %w[up down].include?(vote_type)
      redirect_back fallback_location: root_path, alert: 'Invalid vote' and return
    end

    # If user not signed in, save intent and redirect to sign in.
    unless clerk_signed_in?
      session[:pending_vote] = { 'event_id' => @event.id, 'vote' => vote_type, 'time' => Time.current.to_i }
      Rails.logger.info("[HomeController#vote] saved pending_vote in session: #{session[:pending_vote].inspect}")
      redirect_to sign_in_path and return
    end

    # Signed in — process immediately
    user_id = current_clerk_user_id
    user_email = extract_clerk_user_email

    process_and_publish_vote(@event, vote_type, user_id, user_email)

    redirect_back fallback_location: root_path, notice: 'Your vote was recorded'
  rescue => e
    Rails.logger.error("[HomeController#vote] publish error: #{e.class} #{e.message}\n#{e.backtrace.first(8).join("\n")}")
    redirect_back fallback_location: root_path, alert: 'Could not record vote'
  end

  def process_and_publish_vote(event, vote_type, user_id = nil, user_email = nil)
    user_id ||= current_clerk_user_id
    raise ArgumentError, "user_id required to publish vote" if user_id.blank?

    payload = {
      'event_id' => event.id,
      'external_event_id' => event.external_id,
      'user_id' => user_id,
      'user_email' => user_email,
      'vote' => vote_type,
      'occurred_at' => Time.current.iso8601
    }

    event_class = vote_type == 'up' ? EventUpvoted : EventDownvoted

    # publish into default global stream; projector will handle DB updates.
    Rails.configuration.event_store.publish(event_class.new(data: payload))

    Rails.logger.info("[process_and_publish_vote] published #{event_class.name} for event=#{event.id} user=#{user_id}")
  end

  private

  def set_event
    @event = Event.find(params[:id] || params.dig(:event, :id))
  rescue ActiveRecord::RecordNotFound
    redirect_back fallback_location: root_path, alert: 'Event not found'
  end

  # If we had a pending vote saved (because user was redirected to sign in),
  # try to publish it now that the user is signed in.
  def try_process_pending_vote
    pending = session.delete(:pending_vote)
    return unless pending.present?

    Rails.logger.info("[try_process_pending_vote] processing pending vote for event_id=#{pending['event_id']}, vote=#{pending['vote']}")
    unless clerk_signed_in?
      Rails.logger.warn("[try_process_pending_vote] user not signed in; re-storing pending_vote in session")
      session[:pending_vote] = pending
      return
    end

    event = Event.find_by(id: pending['event_id'])
    unless event
      Rails.logger.warn("[try_process_pending_vote] event not found: #{pending['event_id']}")
      return
    end

    user_id = current_clerk_user_id
    user_email = extract_clerk_user_email

    begin
      process_and_publish_vote(event, pending['vote'], user_id, user_email)
      Rails.logger.info("[try_process_pending_vote] processed pending vote for user=#{user_id}, event=#{event.id}")
    rescue => e
      Rails.logger.error("[try_process_pending_vote] failed to process pending vote: #{e.class} #{e.message}")
      # Re-store pending vote so we can try again later
      session[:pending_vote] = pending
    end
  end

  # Extract primary email from clerk.user or fallbacks
  def extract_clerk_user_email
    return nil unless clerk_responds_to?(:user)

    begin
      user = clerk.user
      return nil unless user

      # Clerk SDK may return EmailAddress objects or plain hashes depending on configuration.
      if user.respond_to?(:email_addresses)
        first = user.email_addresses.first
        # Email address may be a ClerkHttpClient::EmailAddress object or a Hash
        return first.email_address if first.respond_to?(:email_address)
        return first['email_address'] if first.is_a?(Hash) && first['email_address']
        return first.email if first.respond_to?(:email) # some variants
      end

      # Some shapes expose `primary_email_address_id`
      if user.respond_to?(:primary_email_address_id) && user.primary_email_address_id
        primary_id = user.primary_email_address_id
        # fetch full email object using SDK (safe, may make network call)
        if clerk.respond_to?(:sdk) && clerk.sdk.respond_to?(:users)
          begin
            user_record = clerk.sdk.users.get_user(user.id)
            # user_record may be a Hash
            if user_record.is_a?(Hash)
              emails = user_record['email_addresses'] || []
              primary = emails.find { |e| e['id'] == primary_id } || emails.first
              return primary && (primary['email_address'] || primary['email'])
            end
          rescue => e
            Rails.logger.debug("[extract_clerk_user_email] clerk sdk lookup failed: #{e.class} #{e.message}")
          end
        end
      end

      # fallback: sometimes clerk.user has an `email` method
      return user.email if user.respond_to?(:email)

    rescue => e
      Rails.logger.debug("[extract_clerk_user_email] error extracting email: #{e.class} #{e.message}")
      return nil
    end

    nil
  end
end
