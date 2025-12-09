# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController

  def new
    target = ENV['CLERK_SIGN_IN_URL'].presence || 'https://humane-tortoise-24.accounts.dev/sign-in'
  
    redirect_to target, allow_other_host: true
  end
end
