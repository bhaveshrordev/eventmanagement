namespace :billetto do
  desc "Import billetto public events"
  task import: :environment do
    Billetto::EventsFetcher.new.import_all
  end
end
# run with: rails billetto:import
