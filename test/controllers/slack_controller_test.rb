require "test_helper"

class SlackControllerTest < ActionDispatch::IntegrationTest
  test "returns usage for missing command" do
    post "/slack/events", params: { text: "" }

    assert_response :success
    assert_equal "Use `summarize <text>` for a summary or `review <code/text>` for an AI code review.", response.parsed_body["text"]
  end

  test "returns configuration message when api key is missing" do
    previous_api_key = ENV.delete("OPENAI_API_KEY")

    post "/slack/events", params: { command: "/summarize", text: "Rails is a web framework." }

    assert_response :success
    assert_match "OpenAI is not configured yet", response.parsed_body["text"]
  ensure
    ENV["OPENAI_API_KEY"] = previous_api_key if previous_api_key
  end

  test "acknowledges slack slash command immediately when response url is present" do
    post "/slack/events", params: {
      command: "/summarize",
      text: "Rails is a web framework.",
      response_url: "https://hooks.slack.com/commands/example"
    }

    assert_response :success
    assert_equal "ephemeral", response.parsed_body["response_type"]
    assert_equal "Working on it. I will post the summarize here shortly.", response.parsed_body["text"]
  end

  test "supports task included in text for non-slash command calls" do
    previous_api_key = ENV.delete("OPENAI_API_KEY")

    post "/slack/events", params: { text: "review def hello; end" }

    assert_response :success
    assert_match "OpenAI is not configured yet", response.parsed_body["text"]
  ensure
    ENV["OPENAI_API_KEY"] = previous_api_key if previous_api_key
  end
end
