# frozen_string_literal: true

require_relative "lib/empirical/version"

Gem::Specification.new do |spec|
	spec.name = "empirical"
	spec.version = Empirical::VERSION
	spec.authors = ["Joel Drapper", "Stephen Margheim"]
	spec.email = ["joel@drapper.me"]

	spec.summary = "Based on, concerned with, or verifiable by observation or experience rather than theory or pure logic."
	spec.description = "Based on, concerned with, or verifiable by observation or experience rather than theory or pure logic."
	spec.homepage = "https://github.com/yippee-fun/empirical"
	spec.license = "MIT"
	spec.required_ruby_version = ">= 3.1"

	spec.metadata["homepage_uri"] = spec.homepage
	spec.metadata["source_code_uri"] = "https://github.com/yippee-fun/empirical"
	spec.metadata["funding_uri"] = "https://github.com/sponsors/joeldrapper"

	spec.files = Dir[
		"README.md",
		"LICENSE.txt",
		"lib/**/*.rb"
	]

	spec.require_paths = ["lib"]

	spec.metadata["rubygems_mfa_required"] = "true"

	spec.add_dependency "require-hooks", "~> 0.2"
	spec.add_dependency "prism"
end
