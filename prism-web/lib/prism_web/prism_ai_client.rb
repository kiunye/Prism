require "net/http"
require "json"

module PrismWeb
  class PrismAiClient
    def initialize(model: nil, max_tokens: 2000, temperature: 0.1)
      @model = model || Prism.config.ai.model
      @max_tokens = max_tokens
      @temperature = temperature
      @api_key_file = Prism.config.ai.api_key_file
    end

    def generate(prompt)
      case Prism.config.ai.provider
      when :openai then openai_generate(prompt)
      when :anthropic then anthropic_generate(prompt)
      else raise "Unsupported AI provider: #{Prism.config.ai.provider}"
      end
    end

    private

    def openai_generate(prompt)
      api_key = read_api_key
      uri = URI("https://api.openai.com/v1/chat/completions")
      request = Net::HTTP::Post.new(uri, {
        "Authorization" => "Bearer #{api_key}",
        "Content-Type" => "application/json"
      })
      request.body = {
        model: @model,
        messages: [{ role: "user", content: prompt }],
        max_tokens: @max_tokens,
        temperature: @temperature
      }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
      body = JSON.parse(response.body)
      body.dig("choices", 0, "message", "content") || ""
    end

    def anthropic_generate(prompt)
      raise "Anthropic provider not yet implemented"
    end

    def read_api_key
      return ENV["OPENAI_API_KEY"] if ENV["OPENAI_API_KEY"].present?

      key_path = Rails.root.join(@api_key_file)
      key_path.read.strip if key_path.exist?
    end
  end
end