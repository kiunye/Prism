module PrismWeb
  class Dashboard < ActiveRecord::Base
    belongs_to :owner, polymorphic: true, optional: true
    has_many :widgets, dependent: :destroy

    validates :name, presence: true, length: { maximum: 255 }

    def grid_layout
      read_attribute(:grid_layout) || []
    end

    def grid_layout=(value)
      write_attribute(:grid_layout, value)
    end

    def filters
      read_attribute(:filters) || {}
    end

    def filters=(value)
      write_attribute(:filters, value)
    end
  end
end