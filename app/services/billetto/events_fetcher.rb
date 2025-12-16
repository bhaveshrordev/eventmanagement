# app/services/billetto/events_fetcher.rb
require 'net/http'
require 'uri'
require 'json'

module Billetto
  class EventsFetcher
    BASE_HOST = 'billetto.dk'.freeze
    BASE_PATH = '/api/v3/public/events'.freeze
    DEFAULT_LIMIT = 100

    def initialize(api_key: ENV['API_KEY_PAIR'])
      @api_key = api_key || raise(ArgumentError, "Billetto API Key Pair required")
    end

    # Fetch a single page and return the parsed response (hash)
    # params may include :limit and :after
    def fetch_page(limit: DEFAULT_LIMIT, after: nil)
      query = { limit: limit }
      query[:after] = after if after

      uri = URI::HTTPS.build(host: BASE_HOST, path: BASE_PATH, query: URI.encode_www_form(query))
      request = Net::HTTP::Get.new(uri)
      auth_headers.each { |k, v| request[k] = v }

      response = with_retries { perform_request(uri, request) }
      unless response.is_a?(Net::HTTPSuccess)
        raise "Billetto API error: #{response.code} #{response.message} - #{response.body}"
      end

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      Rails.logger.error("[Billetto::EventsFetcher] JSON parse error: #{e.message} body: #{response&.body}")
      {}
    end

    # Import everything by following cursor-based pagination.
    # Processes page-by-page and does batch upserts into DB.
    def import_all(limit: DEFAULT_LIMIT, batch_upsert: true)
      after = nil
      total_imported = 0

      loop do
        page_data = fetch_page(limit: limit, after: after)
        items = Array(page_data['data'] || page_data['events'] || page_data['results'])
        break if items.empty?

        normalized = items.map { |payload| normalized_event_hash(payload) }

        if batch_upsert
          Event.upsert_all(normalized, unique_by: :external_id)
        else
          normalized.each { |attrs| Event.upsert(attrs, unique_by: :external_id) }
        end

        total_imported += items.size
        Rails.logger.info("[Billetto::EventsFetcher] Imported #{items.size} events (total: #{total_imported})")

        break unless page_data['has_more']

        after = items.last['id']
      end

      Rails.logger.info("[Billetto::EventsFetcher] Finished import. total_imported=#{total_imported}")
    rescue StandardError => e
      Rails.logger.error("[Billetto::EventsFetcher] import_all error: #{e.class} #{e.message}")
      raise
    end

    private

    def perform_request(uri, request)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 20
      http.open_timeout = 5

      if Rails.env.development?
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      else
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      end

      http.request(request)
    end

    # Simple retry wrapper for transient errors (socket/timeouts). Adjust retries/backoff as needed.
    def with_retries(max_attempts = 3, base_sleep = 1)
      attempts = 0
      begin
        attempts += 1
        yield
      rescue StandardError => e
        raise if attempts >= max_attempts
        sleep_time = base_sleep * (2 ** (attempts - 1))
        Rails.logger.warn("[Billetto::EventsFetcher] transient error (attempt #{attempts}) #{e.class}: #{e.message}. Retrying in #{sleep_time}s")
        sleep(sleep_time)
        retry
      end
    end

    def auth_headers
      {
        'accept' => 'application/json',
        'Api-Keypair' => @api_key
      }
    end

    # Normalize the payload into a hash suitable for upsert/upsert_all
    def normalized_event_hash(payload)
      {
        external_id: payload['id'].to_s,
        title: payload['title'] || payload['name'],
        description: payload['description'],
        starts_at: payload['startdate'] || payload['start_date'],
        ends_at: payload['enddate'] || payload['end_date'],
        image_url: payload['image_link'] || payload.dig('image', 'url'),
        url: payload['url'],
        branded_url: payload['branded_url'],
        availability: payload['availability'],
        published_state: payload['state'],
        object_kind: payload['kind'] || payload['object'],
        organiser: payload['organiser'],
        minimum_price: payload['minimum_price'],
        categorization: payload['categorization'],
        location: payload['location'],
        created_at: Time.current,
        updated_at: Time.current
      }
    end
  end
end
