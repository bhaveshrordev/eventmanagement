class HomeController < ApplicationController
  before_action :require_clerk_session!

  def index
    order_sql = <<~SQL.squish
    CASE
      WHEN starts_at IS NULL OR starts_at < NOW() THEN 1
    ELSE 0
    END,
    starts_at ASC NULLS LAST
    SQL

    @pagy, @events = pagy(:offset, Event.order(Arel.sql(order_sql)))
  end
end
