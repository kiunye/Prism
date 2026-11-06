module PrismWeb
  class Widget < ActiveRecord::Base
    belongs_to :dashboard
    belongs_to :saved_query, optional: true

    validates :name, presence: true
    validates :chart_type, inclusion: { 
      in: %w[line bar pie area scatter], 
      allow_nil: true 
    }

    def options
      read_attribute(:options) || {}
    end

    def options=(value)
      write_attribute(:options, value)
    end

    def refresh_interval
      read_attribute(:refresh_interval) || {}
    end

    def refresh_interval=(value)
      write_attribute(:refresh_interval, value)
    end
  end
end