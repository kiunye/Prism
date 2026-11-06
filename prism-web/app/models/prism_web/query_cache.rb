module PrismWeb
  class QueryCache < ActiveRecord::Base
    validates :cache_key, presence: true, uniqueness: true

    def query_result
      read_attribute(:query_result) || {}
    end

    def query_result=(value)
      write_attribute(:query_result, value)
    end

    def expired?
      return true unless expires_at

      expires_at < Time.current
    end
  end
end