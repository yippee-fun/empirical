# frozen_string_literal: true

require "prism"
require "securerandom"
require "literal"
require "empirical/version"
require "empirical/name_error"
require "empirical/type_error"
require "empirical/base_processor"
require "empirical/ivar_processor"
require "empirical/eval_processor"
require "empirical/class_callbacks_processor"
require "empirical/signature_processor"
require "empirical/configuration"
require "empirical/types"
require "empirical/signature"

require "require-hooks/setup"

module Empirical
	class VoidClass < BasicObject
		def method_missing(method_name, ...)
			::Kernel.raise "The method `#{method_name}` was called on void. Methods that explicitly declare a void return type should not have their return values used for anything."
		end
	end

	Void = VoidClass.new

	EMPTY_ARRAY = [].freeze
	EVERYTHING = ["**/*"].freeze
	METHOD_METHOD = Module.instance_method(:method)
	OVERLOADED_METHODS = ObjectSpace::WeakKeyMap.new

	TypeStore = Module.new

	CONFIG = Configuration.new
	PROCESSORS = [
		IvarProcessor,
		SignatureProcessor,
		ClassCallbacksProcessor,
	]

	TypedSignatureError = Class.new(SyntaxError)
	NeverError = Class.new(RuntimeError)

	# Initializes Empirical so that code loaded after this point will:
	#   1. be guarded against undefined instance variable reads,
	#   2. permit users to define type checked method definitions, and
	#   3. permit users to define class/module defined callbacks
	#
	# You can pass an array of globs to `include:` and `exclude:`.
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
				process(source, with: PROCESSORS)
			else
				process(source)
			end
		end
	end

	def self.process(source, with: [])
		annotations = []
		tree = Prism.parse(source).value

		Array(with).each do |processor|
			processor.new(annotations:).visit(tree)
		end

		Empirical::EvalProcessor.new(annotations:).visit(tree)

		annotations.sort_by!(&:first)

		buffer = +""
		source_position = 0

		annotations.each do |offset, length, string|
			buffer << source.byteslice(source_position, offset - source_position)
			buffer << string
			source_position = offset + length
		end

		buffer << source.byteslice(source_position, source.bytesize - source_position)
		buffer
	end

	def self.generate_root_overloaded_method(owner, method_name)
		visibility = if owner.public_instance_methods.include?(method_name)
			:public
		elsif owner.protected_instance_methods.include?(method_name)
			:protected
		elsif owner.private_instance_methods.include?(method_name)
			:private
		else
			raise "No existing definition for the method #{method_name}."
		end

		owner.module_eval <<~RUBY
			#{visibility} def #{method_name}(*args, **kwargs, &block)
				::Empirical::OVERLOADED_METHODS[self.method(:#{method_name}).owner][:#{method_name}].each do |sig|
					if sig.positional_params_type === args && sig.keyword_params_type === kwargs
						return sig.method.bind_call(self, *args, **kwargs, &block)
					end
				end

				raise NoMatchingPatternError
			end
		RUBY
	end
end

class Object
	include Literal::Types

	def overload(method_name)
		method_name
	end
end
