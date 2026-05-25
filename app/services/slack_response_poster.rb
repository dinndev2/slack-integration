require "json"
require "net/http"
require "uri"

class SlackResponsePoster
  class RequestError < StandardError; end

  def self.post(response_url:, text:, response_type: "in_channel")
    new(response_url).post(text: text, response_type: response_type)
  end

  def initialize(response_url)
    @uri = URI(response_url)
  end

  def post(text:, response_type:)
    request = Net::HTTP::Post.new(@uri)
    request["Content-Type"] = "application/json"
    request.body = {
      response_type: response_type,
      text: text
    }.to_json

    response = Net::HTTP.start(@uri.hostname, @uri.port, use_ssl: @uri.scheme == "https", open_timeout: 10, read_timeout: 10) do |http|
      http.request(request)
    end

    return if response.is_a?(Net::HTTPSuccess)

    raise RequestError, "Slack response failed with status #{response.code}"
  rescue URI::InvalidURIError, Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError => error
    raise RequestError, error.message
  end
end
