class HomeController < ApplicationController
  before_action :require_clerk_session!

  def index
    @pagy, @events = pagy(:offset, Event.upcoming_first)
  end
end
