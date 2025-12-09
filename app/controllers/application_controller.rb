# app/controllers/application_controller.rb
require 'uri'

class ApplicationController < ActionController::Base
  include Clerk::Authenticatable if defined?(Clerk::Authenticatable)
  helper_method :current_clerk_user_id, :clerk_signed_in?

  ALLOWED_SIGNIN_HOSTS = (ENV.fetch('CLERK_ALLOWED_SIGNIN_HOSTS', '')).split(',').map(&:strip).reject(&:empty?)

  private

  def clerk_handshake_request?
    params.key?('__clerk_handshake') || params.key?('__clerk_db_jwt') || params.key?('__clerk_db_jwt_v2')
  end

  # Require a clerk session: but DO NOT redirect if this is the clerk handshake callback
  def require_clerk_session!
    return if clerk_handshake_request?

    return if clerk_signed_in?

    signin = ENV['CLERK_SIGN_IN_URL'] || '/users/sign_in'

    # If local path, safe to redirect
    if signin.start_with?('/')
      redirect_to signin and return
    end

    begin
      uri = URI.parse(signin)
      if ALLOWED_SIGNIN_HOSTS.include?(uri.host)
        redirect_to signin, allow_other_host: true and return
      else
        Rails.logger.warn("[Clerk] signin host not allowed: #{uri.host}. Rendering sign-in link instead.")
        render_signin_link(signin) and return
      end
    rescue URI::InvalidURIError
      redirect_to signin and return
    end
  end

  def render_signin_link(signin_url)
    render inline: <<~HTML, layout: 'application', status: :unauthorized
      <h1>Sign in required</h1>
      <p>Please sign in to continue:</p>
      <p><a href="#{ERB::Util.html_escape(signin_url)}" target="_blank" rel="noopener noreferrer">Sign in</a></p>
    HTML
  end

  def current_clerk_user_id
    if clerk_responds_to?(:user)
      begin
        user = clerk.user
        return user.id if user && user.respond_to?(:id)
      rescue => e
        Rails.logger.debug("[Clerk] clerk.user access raised: #{e.class} #{e.message}")
      end
    end

    if clerk_responds_to?(:session_claims)
      begin
        claims = clerk.session_claims
        return claims['sub'] if claims.is_a?(Hash) && claims['sub']
      rescue => e
        Rails.logger.debug("[Clerk] clerk.session_claims raised: #{e.class} #{e.message}")
      end
    end

    if clerk_responds_to?(:session_token)
      token = clerk.session_token
      return token if token.present? # token as fallback; ideally verify it with SDK
    end

    return cookies[:__dev_clerk_user_id] if Rails.env.development? && cookies[:__dev_clerk_user_id].present?

    nil
  end

  def clerk_signed_in?
    # prefer clerk.user if present
    if clerk_responds_to?(:user)
      begin
        return true if clerk.user.present?
      rescue
      end
    end

    if clerk_responds_to?(:session_claims)
      begin
        return clerk.session_claims.present?
      rescue
      end
    end

    if clerk_responds_to?(:session_token)
      return clerk.session_token.present?
    end

    false
  end

  def clerk_responds_to?(m)
    clerk.respond_to?(m)
  rescue StandardError
    false
  end
end
