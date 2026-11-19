# frozen_string_literal: true

class Empirical::Configuration
	def initialize
		@mutex = Mutex.new
		@include = []
		@exclude = []
	end

	#: (*String) -> void
	def include(*patterns)
		@mutex.synchronize do
			@include.concat(patterns)
			@cache_key = nil
		end
	end

	#: (*String) -> void
	def exclude(*patterns)
		@mutex.synchronize do
			@exclude.concat(patterns)
			@cache_key = nil
		end
	end

	#: () -> String
	def cache_key
		@mutex.synchronize do
			@cache_key ||= [@include, @exclude].inspect.freeze
		end
	end

	#: (String) -> bool
	def match?(path)
		return false unless String === path
		path = File.absolute_path(path)
		return false if @exclude.any? { |pattern| File.fnmatch?(pattern, path) }
		return true if @include.any? { |pattern| File.fnmatch?(pattern, path) }
		false
	end
end
