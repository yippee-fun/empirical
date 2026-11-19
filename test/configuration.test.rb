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

test "patterns match like Dir.glob" do
	config = Empirical::Configuration.new
	config.include("#{Dir.pwd}/lib/**/*")
	config.include("#{Dir.pwd}/test/{example,excluded}.rb")

	assert config.match?("lib/empirical.rb")
	assert config.match?("lib/empirical/name_error.rb")
	assert config.match?("test/example.rb")
	refute config.match?("test/configuration.test.rb")
end

test "a single star doesn't cross directories" do
	config = Empirical::Configuration.new
	config.include("#{Dir.pwd}/lib/*")

	assert config.match?("lib/empirical.rb")
	refute config.match?("lib/empirical/name_error.rb")
end

test "the cache key changes with the patterns" do
	config = Empirical::Configuration.new
	keys = [config.cache_key]

	config.include("#{Dir.pwd}/lib/**/*.rb")
	keys << config.cache_key

	config.exclude("#{Dir.pwd}/lib/**/version.rb")
	keys << config.cache_key

	assert_equal 3, keys.uniq.size
	assert_equal keys.last, config.cache_key
end
