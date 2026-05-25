require "json"
require "net/http"
require "uri"

class OpenAiTextAssistant
  API_URI = URI("https://api.openai.com/v1/responses")
  DEFAULT_MODEL = "gpt-4.1-nano"

  class ConfigurationError < StandardError; end
  class RequestError < StandardError; end

  TASK_INSTRUCTIONS = {
    "summarize" => <<~PROMPT.squish,
      Summarize the user's text clearly and briefly. Keep the summary faithful
      to the provided text. Use bullets only when they improve readability.

      Please strictly follow this format
        Summary:
          Customer was charged twice for invoice INV-2049 and is requesting an urgent refund. Previous support response did not resolve the issue.

          Priority: High

          Category: Billing

          Action Items:
          - Investigate duplicate charge
          - Process refund if valid
          - Follow up with customer within 24 hours

          Risk:
          Customer may cancel subscription if unresolved
    PROMPT
    "review" => <<~PROMPT.squish
      Review the user's code or technical text. Focus on bugs, security issues,
      correctness, maintainability, and missing tests. Put the most important
      findings first. If there are no clear issues, say so briefly.
    PROMPT
  }.freeze

  def initialize(api_key: ENV["OPENAI_API_KEY"], model: ENV.fetch("OPENAI_MODEL", DEFAULT_MODEL))
    @api_key = api_key
    @model = model
  end

  def configured?
    @api_key.present?
  end

  def run(task:, text:)
    raise ConfigurationError, "OPENAI_API_KEY is not configured" unless configured?

    instructions = TASK_INSTRUCTIONS.fetch(task)
    response = post_response(instructions: instructions, text: text)

    extract_output_text(response).presence || raise(RequestError, "OpenAI response did not include text output")
  end

  private

  def post_response(instructions:, text:)
    request = Net::HTTP::Post.new(API_URI)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"
    request.body = {
      model: @model,
      instructions: instructions,
      input: text
    }.to_json

    http_response = Net::HTTP.start(API_URI.hostname, API_URI.port, use_ssl: true, open_timeout: 10, read_timeout: 60) do |http|
      http.request(request)
    end

    body = JSON.parse(http_response.body)
    return body if http_response.is_a?(Net::HTTPSuccess)

    message = body.dig("error", "message") || "OpenAI request failed with status #{http_response.code}"
    raise RequestError, message
  rescue JSON::ParserError
    raise RequestError, "OpenAI returned an invalid JSON response"
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError => error
    raise RequestError, error.message
  end

  def extract_output_text(response)
    response["output_text"] || response.fetch("output", []).flat_map { |item|
      item.fetch("content", []).filter_map { |content| content["text"] if content["type"] == "output_text" }
    }.join("\n")
  end
end
