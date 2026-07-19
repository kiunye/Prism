# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "prism-web"
  spec.version       = "0.1.0"
  spec.authors       = ["Prism Contributors"]
  spec.email         = ["contributors@prism.example"]

  spec.summary       = "Mountable Rails engine for Prism BI"
  spec.description   = "Mountable Rails 8 engine providing SQL editor, schema browser, dashboards, and AI querying for Prism."
  spec.homepage      = "https://github.com/prism/prism"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.files = Dir.glob("{lib,test}/**/*") + %w[README.md Rakefile Gemfile]
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "rails", ">= 8.0", "< 9.0"
  spec.add_runtime_dependency "prism-core", "~> 0.1"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "brakeman", "~> 7.0"
  spec.add_development_dependency "bundler-audit", "~> 0.9"
end