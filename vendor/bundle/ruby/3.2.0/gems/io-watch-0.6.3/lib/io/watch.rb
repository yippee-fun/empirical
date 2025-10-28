# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative 'watch/version'
require_relative 'watch/monitor'

# @namespace
class IO
	# @namespace
	module Watch
		# Create a new monitor.
		def self.new(...)
			Monitor.new(...)
		end
	end
end
