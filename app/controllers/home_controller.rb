class HomeController < ApplicationController
  before_action :require_clerk_session!

  def index
    @events = Event.all.limit(105)
  end
end
