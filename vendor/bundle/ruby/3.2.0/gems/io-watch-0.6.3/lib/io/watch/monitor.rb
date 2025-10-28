# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require 'json'

class IO
	module Watch
		# Represents a list of roots to watch for changes.
		class Monitor
			# The path to the compiled `io-watch` command.
			def self.command_path
				if extension_path = Gem.loaded_specs['io-watch']&.extension_dir
					if File.exist?(extension_path)
						return File.join(extension_path, 'bin', 'io-watch')
					end
				end
				
				return File.join(__dir__, '..', '..', '..', 'ext/io-watch')
			end
			
			COMMAND_PATH = self.command_path
			
			# Initialize the monitor with a list of roots to watch.
			#
			# The roots are the paths that will be watched for changes, recursively.
			#
			# @parameter roots [Array(String)] The list of root directories to watch. Changes to these directories, and their children, recursively, will be reported.
			# @parameter latency [Float] The latency to use when watching the filesystem.
			def initialize(roots, latency: nil)
				@roots = roots
				@latency = latency
			end
			
			# Run the monitor and yield events as they occur.
			#
			# The values yielded are hashes with at least the following:
			# - `:root` - The root path that the event occurred in.
			#
			# There may be other platform specific keys present.
			#
			# @yields {|event| ...} Yielded for each event that occurs.
			#   @parameter event [Hash] The event that occurred.
			def run
				environment = {}
				if @latency
					environment['IO_WATCH_LATENCY'] = @latency.to_s
				end
				
				IO.pipe do |input, output|
					pid = Process.spawn(environment, self.class.command_path, *@roots, out: output)
					output.close
					
					input.each_line do |line|
						event = JSON.parse(line, symbolize_names: true)
						
						if index = event[:index]
							event[:root] = @roots[index]
						end
						
						yield event
					end
				ensure
					Process.kill('TERM', pid) if pid
				end
			end
		end
	end
end
