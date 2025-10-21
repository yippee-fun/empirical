# frozen_string_literal: true

require "prism"
require "securerandom"

require "empirical/version"
require "empirical/name_error"
require "empirical/base_processor"
require "empirical/processor"
require "empirical/configuration"

require "require-hooks/setup"

module Empirical
	EMPTY_ARRAY = [].freeze
	EVERYTHING = ["**/*"].freeze
	METHOD_METHOD = Module.instance_method(:method)

	CONFIG = Configuration.new
	TypedSignatureError = Class.new(SyntaxError)

	class TypeError < ::TypeError
		def self.argument_type_error(name:, value:, expected:, method_name:, context:)
			owner = context.method(method_name).owner
			sign = owner.singleton_class? ? "." : "#"

			new(<<~MESSAGE)
				Method #{method_name} called with the wrong type for the argument #{name}.

				  #{owner.name}#{sign}#{method_name}
				    #{name}:
				      Expected: #{expected.inspect}
				      Actual (#{value.class}): #{value.inspect}
			MESSAGE
		end

		def self.return_type_error(value:, expected:, method_name:, context:)
			owner = context.method(method_name).owner
			sign = owner.singleton_class? ? "." : "#"

			new(<<~MESSAGE)
				Method #{method_name} returned the wrong type.

				  #{owner.name}#{sign}#{method_name}
				    Expected: #{expected.inspect}
				    Actual (#{value.class}): #{value.inspect}
			MESSAGE
		end
	end

	# Initializes Empirical so that code loaded after this point will be
	# guarded against undefined instance variable reads. You can pass an array
	# of globs to `include:` and `exclude:`.
	#
	# ```ruby
	# Empirical.init(
	#   include: ["#{Dir.pwd}/**/*"],
	#   exclude: ["#{Dir.pwd}/vendor/**/*"]
	# )
	# ```
	#: (include: Array[String], exclude: Array[String]) -> void
	def self.init(include: EMPTY_ARRAY, exclude: EMPTY_ARRAY)
		CONFIG.include(*include)
		CONFIG.exclude(*exclude)

		RequireHooks.source_transform(
			patterns: EVERYTHING,
			exclude_patterns: EMPTY_ARRAY
		) do |path, source|
			source ||= File.read(path)

			if CONFIG.match?(path)
				Processor.call(source)
			else
				BaseProcessor.call(source)
			end
		end
	end

	# For internal use only. This method pre-processes arguments to an eval method.
	#: (Object, Symbol, *untyped)
	def self.__process_eval_args__(receiver, method_name, *args)
		method = METHOD_METHOD.bind_call(receiver, method_name)
		owner = method.owner

		source, file = nil

		case method_name
		when :class_eval, :module_eval
			if Module == owner
				source, file = args
			end
		when :instance_eval
			if BasicObject == owner
				source, file = args
			end
		when :eval
			if Kernel == owner
				source, binding, file = args
			elsif Binding == owner
				source, file = args
			end
		end

		if String === source
			file ||= caller_locations(1, 1).first.path

			if CONFIG.match?(file)
				args[0] = Processor.call(source)
			else
				args[0] = BaseProcessor.call(source)
			end
		end

		args
	rescue ::NameError
		args
	end

	#: () { () -> void } -> Proc
	def self.__eval_block_from_forwarding__(*, &block)
		block
	end
end
