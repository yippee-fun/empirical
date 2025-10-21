# frozen_string_literal: true

test do
	config = Empirical::Configuration.new
	config.include("#{Dir.pwd}/lib/**/*.rb")
	config.exclude("#{Dir.pwd}/lib/**/version.rb")

	assert config.match?("lib/empirical/name_error.rb")
	refute config.match?("lib/empirical/version.rb")
	refute config.match?(Object.new)
	refute config.match?(nil)
end
