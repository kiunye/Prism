# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "prism-core"
  spec.version       = "0.1.0"
  spec.authors       = ["Prism Contributors"]
  spec.email         = ["contributors@prism.example"]

  spec.summary       = "Core query engine and read-only enforcement for Prism"
  spec.description   = "Pure Ruby query engine with read-only enforcement, variable interpolation, and schema inspection for Prism BI."
  spec.homepage      = "https://github.com/prism/prism"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.files = Dir.glob("{lib,test}/**/*") + %w[README.md Rakefile Gemfile]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "bundler-audit", "~> 0.9"
end