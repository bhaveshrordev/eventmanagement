class HomeController < ApplicationController
  before_action :require_clerk_session!

  def index
    @pagy, @events = pagy(:offset, Event.all) 
  end
end
