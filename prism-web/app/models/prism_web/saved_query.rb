module PrismWeb
  class SavedQuery < ActiveRecord::Base
    belongs_to :owner, polymorphic: true, optional: true
    has_one :share_token, dependent: :destroy

    validates :name, presence: true, length: { maximum: 255 }
    validates :sql, presence: true
    validates :visibility, inclusion: { in: %w[owner all] }

    scope :accessible_by_owner, ->(owner) {
      where("visibility = 'all' OR (owner_type = ? AND owner_id = ?)", owner[:type], owner[:id])
    }

    def variables
      read_attribute(:variables) || {}
    end

    def variables=(value)
      write_attribute(:variables, value)
    end

    def accessible_by_owner?(owner)
      visibility == "all" || (owner_type == owner[:type] && owner_id == owner[:id])
    end

    def shareable_token
      share_token&.token
    end

    def generate_share_token!
      share_token&.destroy
      ShareToken.create!(
        resource_type: "SavedQuery",
        resource_id: id,
        token: SecureRandom.hex(Prism.config.sharing.token_length / 2)
      )
    end

    def expire_share_token!
      share_token&.destroy
    end
  end
end