FactoryBot.define do
  factory :admin_http_request, class: 'Admin::HttpRequest' do
    integration_type { 'tomtom' }
    trace_id { SecureRandom.uuid }
    http_method { 'GET' }
    url { 'https://api.tomtom.com/search/2/geocode/Betim.json?countrySet=BR&key=[FILTERED]' }
    request_headers { { 'accept' => '*/*', 'host' => 'api.tomtom.com' } }
    status_code { 200 }
    status_message { 'OK' }
    response_headers { { 'content-type' => 'application/json' } }
    response_content_type { 'application/json' }
    response_body { '{"results":[]}' }
    response_size { 14 }
    duration_ms { 120 }
  end
end
