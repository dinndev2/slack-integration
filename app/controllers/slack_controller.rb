class SlackController < ApplicationController
  def events
    task, text = parse_command
    response_url = params[:response_url].to_s

    return render_slack_message(usage_text) unless task
    return render_slack_message(response_text(task: task, text: text)) if response_url.blank?

    run_async_slack_response(task: task, text: text, response_url: response_url)
    render_slack_message("Working on it. I will post the #{task} here shortly.", response_type: "ephemeral")
  end

  private

  def parse_command
    task = params[:command].to_s.delete_prefix("/").strip
    text = params[:text].to_s.strip

    return [ task, text ] if OpenAiTextAssistant::TASK_INSTRUCTIONS.key?(task) && text.present?

    parse_text_command(text)
  end

  def parse_text_command(command_text)
    task, text = command_text.strip.split(/\s+/, 2)
    return [ task, text.to_s.strip ] if OpenAiTextAssistant::TASK_INSTRUCTIONS.key?(task) && text.present?

    [ nil, command_text ]
  end

  def response_text(task:, text:)
    OpenAiTextAssistant.new.run(task: task, text: text)
  rescue OpenAiTextAssistant::ConfigurationError
    "OpenAI is not configured yet. Set OPENAI_API_KEY, then try `summarize your text` or `review your code`."
  rescue OpenAiTextAssistant::RequestError => error
    "OpenAI request failed: #{error.message}"
  end

  def usage_text
    "Use `summarize <text>` for a summary or `review <code/text>` for an AI code review."
  end

  def run_async_slack_response(task:, text:, response_url:)
    Thread.new do
      Rails.application.executor.wrap do
        SlackResponsePoster.post(response_url: response_url, text: response_text(task: task, text: text))
      rescue SlackResponsePoster::RequestError => error
        Rails.logger.error("Slack response_url post failed: #{error.message}")
      end
    end
  end

  def render_slack_message(text, response_type: "in_channel")
    render json: {
      response_type: response_type,
      text: text
    }
  end
end
