# frozen_string_literal: true

require "prism"
require "literal"
require "empirical/version"
require "empirical/name_error"
require "empirical/type_error"
require "empirical/base_processor"
require "empirical/ivar_processor"
require "empirical/eval_processor"
require "empirical/fun"
require "empirical/fun_parser"
require "empirical/fun_generator"
require "empirical/signature_processor"
require "empirical/configuration"

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
	IVAR_TYPE = ObjectSpace::WeakKeyMap.new
	INHERITED_IVAR_TYPES = ObjectSpace::WeakKeyMap.new
	TYPED_IVAR_NAMES = {}

	module TypeStore
		# Redefining replaces the type, so reloading a file doesn’t warn or leak.
		def self.store(name, type)
			remove_const(name) if const_defined?(name, false)
			const_set(name, type)
		end
	end

	CONFIG = Configuration.new
	PROCESSORS = [
		IvarProcessor,
		SignatureProcessor,
	]

	TypedSignatureError = Class.new(SyntaxError)
	NeverError = Class.new(RuntimeError)

	# Initializes Empirical so that code loaded after this point will:
	#   1. be guarded against undefined instance variable reads,
	#   2. have its instance variable writes type checked against `prop` declarations, and
	#   3. permit users to define type checked method definitions with `fun`
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

		return if @initialized
		@initialized = true

		RequireHooks.source_transform(
			patterns: EVERYTHING,
			exclude_patterns: EMPTY_ARRAY
		) do |path, source|
			source ||= File.binread(path)

			if CONFIG.match?(path)
				process(source, with: PROCESSORS, path:)
			else
				process(source, path:)
			end
		end
	end

	def self.process(source, with: [], path: nil)
		annotations = []
		result = Prism.parse(source)
		tree = result.value

		[EvalProcessor, *with].each do |processor|
			processor.new(annotations:, source:, path:).visit(tree)
		end

		# At the same offset, closings come first, then plain edits, then openings. See BaseProcessor#wrap.
		annotations = annotations.sort_by.with_index do |(offset, _, _, order), index|
			[offset, *(order || [1, 0, 0]), index]
		end

		buffer = "".b
		source_position = 0

		annotations.each do |offset, length, string|
			raise "Overlapping annotations at byte #{offset}." if offset < source_position

			buffer.append_as_bytes(source.byteslice(source_position, offset - source_position), string)
			source_position = offset + length
		end

		buffer.append_as_bytes(source.byteslice(source_position, source.bytesize - source_position))
		buffer.force_encoding(result.encoding)
	end

	def self.declare_ivar_type(owner, ivar, type)
		# Methods inherited from an ancestor check writes against the ancestor’s type.
		owner.ancestors.each do |ancestor|
			next if ancestor.equal?(owner)

			declared = IVAR_TYPE[ancestor]

			if declared&.key?(ivar) && declared[ivar] != type
				raise ArgumentError, "#{ivar} is already declared on #{ancestor.inspect} with a different type. A subclass can’t change the type of an inherited prop."
			end
		end

		(IVAR_TYPE[owner] ||= {})[ivar] = type
		TYPED_IVAR_NAMES[ivar] = true
		INHERITED_IVAR_TYPES.clear
	end

	# For internal use only. Returns the value, or raises if the ivar has a type and the value doesn’t match.
	def self.__check_ivar__(object, name, value)
		# Most ivars have no type on any class, and looking up the object’s class is the slow part.
		return value unless TYPED_IVAR_NAMES.key?(name)

		types = ivar_types_for(CLASS_METHOD.bind_call(object))

		if types.key?(name) && !(types[name] === value)
			raise TypeError.ivar_type_error(name:, value:, expected: types[name], context: object)
		end

		value
	end

	# The ivar types declared on a class and its ancestors.
	private_class_method def self.ivar_types_for(owner)
		INHERITED_IVAR_TYPES[owner] ||= owner.ancestors.reverse_each.with_object({}) do |ancestor, types|
			declared = IVAR_TYPE[ancestor]
			types.merge!(declared) if declared
		end
	end
end

class Object
	include Literal::Types
end

Empirical::CLASS_METHOD = Object.instance_method(:class)
Empirical::INSTANCE_VARIABLE_SET_METHOD = Object.instance_method(:instance_variable_set)
Empirical::INSTANCE_VARIABLE_GET_METHOD = Object.instance_method(:instance_variable_get)
Empirical::DEFINE_METHOD_METHOD = Module.instance_method(:define_method)
Empirical::ATTR_READER_METHOD = Module.instance_method(:attr_reader)

class BasicObject
	def self.prop(name, type, reader: nil, writer: nil, predicate: nil)
		raise ArgumentError unless reader    in nil | :public | :protected | :private
		raise ArgumentError unless writer    in nil | :public | :protected | :private
		raise ArgumentError unless predicate in nil | :public | :protected | :private

		ivar = :"@#{name}"

		::Empirical.declare_ivar_type(self, ivar, type)

		if reader
			::Empirical::ATTR_READER_METHOD.bind_call(self, name)

			__send__ reader, name
		end

		if writer
			writer_method_name = :"#{name}="

			::Empirical::DEFINE_METHOD_METHOD.bind_call(self, writer_method_name) do |value|
				::Empirical::INSTANCE_VARIABLE_SET_METHOD.bind_call(self, ivar, ::Empirical.__check_ivar__(self, ivar, value))
			end

			__send__ writer, writer_method_name
		end

		if predicate
			predicate_method_name = :"#{name}?"

			::Empirical::DEFINE_METHOD_METHOD.bind_call(self, predicate_method_name) do
				!!::Empirical::INSTANCE_VARIABLE_GET_METHOD.bind_call(self, ivar)
			end

			__send__ predicate, predicate_method_name
		end
	end
end
