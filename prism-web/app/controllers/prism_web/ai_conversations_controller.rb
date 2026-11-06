module PrismWeb
  class AiConversationsController < ApplicationController
    before_action :set_ai_conversation, only: [:show, :update, :destroy, :create_message]

    def index
      @ai_conversations = AiConversation.where(
        owner_type: Current.owner[:type],
        owner_id: Current.owner[:id]
      ).order(updated_at: :desc)
      render :index
    end

    def show
      render :show
    end

    def create
      @ai_conversation = AiConversation.new(ai_conversation_params)
      @ai_conversation.owner_type = Current.owner[:type]
      @ai_conversation.owner_id = Current.owner[:id]
      @ai_conversation.context = build_schema_context

      if @ai_conversation.save
        render json: { data: @ai_conversation }, status: :created
      else
        render json: { errors: @ai_conversation.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      if @ai_conversation.update(ai_conversation_params)
        render json: { data: @ai_conversation }, status: :ok
      else
        render json: { errors: @ai_conversation.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @ai_conversation.destroy
      head :no_content
    end

    def create_message
      message = params[:message]

      begin
        ai_response = generate_ai_response(message)
        save_message(@ai_conversation, "user", message)
        save_message(@ai_conversation, "assistant", ai_response)

        render json: { data: { response: ai_response } }, status: :ok
      rescue => e
        render json: { errors: [e.message] }, status: :internal_server_error
      end
    end

    private

    def generate_ai_response(message)
      schema_context = @ai_conversation.context || build_schema_context
      prompt = build_prompt(message, schema_context)

      response_text = ai_client.generate(prompt)
      extract_sql(response_text)
    end

    def build_prompt(message, schema_context)
      <<~PROMPT
        You are Prism AI, an SQL generator for read-only database queries.
        
        Database Schema:
        #{schema_context}
        
        User request: #{message}
        
        Generate only valid read-only SQL. Respond with the SQL query.
      PROMPT
    end

    def ai_client
      @ai_client ||= PrismAiClient.new(
        model: Prism.config.ai.model,
        max_tokens: Prism.config.ai.max_tokens,
        temperature: Prism.config.ai.temperature
      )
    end

    def build_schema_context
      schema_context_builder.build(Prism.config.connections.default_slug)
    end

    def extract_sql(text)
      sql_match = text.match(/```(?:sql)?\s*\n?(.*?)\n?```/m)
      sql_match ? sql_match[1].strip : text.strip
    end

    def save_message(conversation, role, content)
      conversation.messages = (conversation.messages || []) + [{
        role: role,
        content: content,
        timestamp: Time.current.iso8601
      }]
      conversation.save!
    end

    def set_ai_conversation
      @ai_conversation = AiConversation.find(params[:id])

      unless @ai_conversation.owner_type == Current.owner[:type] && @ai_conversation.owner_id == Current.owner[:id]
        render json: { errors: ["Access denied"] }, status: :forbidden
      end
    end

    def ai_conversation_params
      params.require(:ai_conversation).permit(:title, :context)
    end
  end
end