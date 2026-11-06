module PrismWeb
  class ShareToken < ActiveRecord::Base
    before_validation :generate_token, on: :create
    validate :expires_at_in_future, if: -> { expires_at.present? }

    belongs_to :resource, polymorphic: true, optional: true

    def generate_token
      return if token.present?

      length = Prism.config.sharing.token_length || 32
      self.token = SecureRandom.hex(length / 2)
    end

    def expires_at_in_future
      errors.add(:expires_at, "must be in the future") if expires_at <= Time.current
    end

    def accessible?
      return true if expires_at.blank?

      expires_at > Time.current
    end

    def scoped_to?(resource_type, resource_id)
      self.resource_type == resource_type && self.resource_id == resource_id
    end

    def resource
      self.resource_type.constantize.find(self.resource_id) if self.resource_type.present?
    end
  end
end