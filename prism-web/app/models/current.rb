# frozen_string_literal: true

module Current
  def self.[](key)
    Thread.current["current_#{key}"]
  end

  def self.[]=(key, value)
    Thread.current["current_#{key}"] = value
  end

  def self.owner
    self[:owner]
  end

  def self.owner=(value)
    self[:owner] = value
  end

  def self.attributes
    Thread.current.keys.select { |k| k.start_with?("current_") }.each_with_object({}) do |key, hash|
      hash[key.sub("current_", "").to_sym] = Thread.current[key]
    end
  end

  def self.reset
    Thread.current.keys.select { |k| k.start_with?("current_") }.each do |key|
      Thread.current[key] = nil
    end
  end
end