# Slack AI Integration

Rails API endpoint for Slack commands backed by OpenAI text generation.

## OpenAI setup

Set your API key before running the app:

```sh
export OPENAI_API_KEY="your-api-key"
```

The app defaults to `gpt-4.1-nano`, OpenAI's fastest, most cost-efficient GPT-4.1 model. You can override it:

```sh
export OPENAI_MODEL="gpt-4.1-mini"
```

## Slack usage

Send one of these commands to `POST /slack/events`:

```text
summarize <text to summarize>
review <code or technical text to review>
```

If `OPENAI_API_KEY` is not set, the Slack endpoint returns a configuration message instead of calling OpenAI.

## Tests

```sh
bin/rails test
```
