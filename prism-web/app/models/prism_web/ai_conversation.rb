module PrismWeb
  class AiConversation < ActiveRecord::Base
    belongs_to :owner, polymorphic: true, optional: true

    validates :title, presence: true

    def messages
      read_attribute(:messages) || []
    end

    def messages=(value)
      write_attribute(:messages, value)
    end

    def context
      read_attribute(:context) || ""
    end

    def context=(value)
      write_attribute(:context, value)
    end
  end
end