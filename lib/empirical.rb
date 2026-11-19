# frozen_string_literal: true

require "digest"
require "prism"
require "literal"
require "empirical/version"
require "empirical/name_error"
require "empirical/type_error"
require "empirical/undeclared_instance_variable_error"
require "empirical/base_processor"
require "empirical/ivar_processor"
require "empirical/eval_processor"
require "empirical/fun"
require "empirical/fun_parser"
require "empirical/literal_node"
require "empirical/fun_checker"
require "empirical/fun_generator"
require "empirical/static_check"
require "empirical/signature_processor"
require "empirical/definition_hooks_processor"
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
	CLOSED_MODULES = ObjectSpace::WeakKeyMap.new
	CLOSED_MODULE_NAMES = {}
	CLOSED_MUTEX = Mutex.new

	# Keyed by [path, line, name], which identifies a method definition through `source_location` and `original_name`.
	FUN_TYPES = {}
	FunTypes = Data.define(:parameter_types, :return_type)

	# The return type of an `itself` method, which depends on the receiver.
	module Itself; end

	module TypeStore
		# The stored types an ivar’s writes are inlined against, by owner and ivar. A class body that
		# is reopened declares the ivar again, so there can be more than one.
		INLINED = ObjectSpace::WeakKeyMap.new

		# The ivars a subclass has narrowed, by owner.
		NARROWED = ObjectSpace::WeakKeyMap.new

		# Stands in for the inlined type of an ivar a subclass has narrowed, so writes in the owner’s
		# methods take the runtime check, which knows the receiver’s class.
		module Narrowed
			def self.===(_value) = false
		end

		# Redefining replaces the type, so reloading a file doesn’t warn or leak. Returns the type.
		def self.store(name, type, owner = nil, ivar = nil)
			narrowed = false

			if owner
				((INLINED[owner] ||= {})[ivar] ||= Set[]) << name
				narrowed = NARROWED[owner]&.include?(ivar)
			end

			remove_const(name) if const_defined?(name, false)
			const_set(name, narrowed ? Narrowed : type)

			type
		end

		def self.narrow(owner, ivar)
			(NARROWED[owner] ||= Set[]) << ivar

			INLINED[owner]&.fetch(ivar, nil)&.each do |name|
				remove_const(name)
				const_set(name, Narrowed)
			end
		end

		MISSING = Object.new.freeze

		# For a type that may not have been stored yet.
		def self.lookup(name)
			const_defined?(name, false) ? const_get(name, false) : MISSING
		end
	end

	CONFIG = Configuration.new
	PROCESSORS = [
		IvarProcessor,
		SignatureProcessor,
		DefinitionHooksProcessor,
	]

	SOURCE_DIGEST = Dir[File.join(__dir__, "{empirical.rb,empirical/**/*.rb}")].each_with_object(Digest::SHA256.new) do |path, digest|
		digest << File.binread(path)
	end.hexdigest.freeze

	TypedSignatureError = Class.new(SyntaxError)
	NeverError = Class.new(RuntimeError)

	# Raised when a file loads, for a type mistake that is visible in its source.
	StaticTypeError = Class.new(::TypeError)

	# Initializes Empirical so that code loaded after this point will:
	#   1. be guarded against undefined instance variable reads,
	#   2. have its instance variable writes type checked against `has` declarations,
	#   3. permit users to define type checked method definitions with `fun`, and
	#   4. call the `defined`, `reopened` and `redefined` hooks when a class or module body closes
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

		# Bootsnap caches the transformed code, so its key has to change whenever the transform would.
		if defined?(RequireHooks::Bootsnap)
			RequireHooks::Bootsnap.add_version_hash { cache_key }
		end

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

	#: () -> String
	def self.cache_key
		"#{SOURCE_DIGEST}-#{Prism::VERSION}-#{CONFIG.cache_key}"
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

	# A subclass may narrow an inherited ivar to a subtype. The ancestor’s methods then check their
	# writes against the receiver’s class at runtime, so they can’t write what the subclass rejects.
	def self.declare_ivar_type(owner, ivar, type)
		owner.ancestors.each do |ancestor|
			next if ancestor.equal?(owner)

			declared = IVAR_TYPE[ancestor]

			next unless declared&.key?(ivar)

			inherited = declared[ivar]

			next if inherited == type

			unless Literal.subtype?(type, inherited)
				raise ArgumentError, "#{ivar} is declared on #{ancestor.inspect} as #{inherited.inspect}, and #{type.inspect} isn’t a subtype of it. A subclass can only narrow the type of an inherited instance variable."
			end

			TypeStore.narrow(ancestor, ivar)
		end

		(IVAR_TYPE[owner] ||= {})[ivar] = type
		INHERITED_IVAR_TYPES.clear
	end

	# For internal use only. Returns the value, or raises if the ivar isn’t declared or the value doesn’t match its type.
	def self.__check_ivar__(object, name, value)
		# `object.class` is several times faster than binding Kernel#class, but it can be overridden,
		# so it’s only trusted to accept a write. Anything else is checked again against the real class.
		if Object === object
			types = INHERITED_IVAR_TYPES[object.class]
			return value if types&.key?(name) && types[name] === value
		end

		# The ivars of a class or module itself are declared on its singleton class.
		owner = (Module === object) ? SINGLETON_CLASS_METHOD.bind_call(object) : CLASS_METHOD.bind_call(object)

		type = ivar_types_for(owner).fetch(name) do
			raise UndeclaredInstanceVariableError.new(object, name)
		end

		raise TypeError.ivar_type_error(name:, value:, expected: type, context: object) unless type === value

		value
	end

	# For internal use only. Takes what `attr_writer` or `attr_accessor` returned and redefines the writers
	# so they type check, keeping their visibility.
	def self.__check_writers__(owner, method_names)
		method_names.each do |method_name|
			next unless method_name.end_with?("=")

			ivar = "@#{method_name.name.delete_suffix('=')}"

			visibility = if PRIVATE_METHOD_DEFINED_METHOD.bind_call(owner, method_name)
				PRIVATE_METHOD
			elsif PROTECTED_METHOD_DEFINED_METHOD.bind_call(owner, method_name)
				PROTECTED_METHOD
			else
				PUBLIC_METHOD
			end

			MODULE_EVAL_METHOD.bind_call(owner, <<~RUBY, __FILE__, __LINE__ + 1)
				def #{method_name}(value)
					#{ivar} = ::Empirical.__check_ivar__(self, :#{ivar}, value)
				end
			RUBY

			visibility.bind_call(owner, method_name)
		end

		method_names
	end

	# For internal use only. Called after each `fun` is defined. Returns the name, as the `def` would.
	def self.__declare_fun_types__(path, line, name, parameter_types, return_type)
		FUN_TYPES[[path, line, name]] = FunTypes.new(parameter_types: parameter_types.freeze, return_type:)
		name
	end

	# The types a method was defined with, or nil if it wasn’t defined with `fun`.
	def self.fun_types(method)
		path, line = method.source_location
		FUN_TYPES[[path, line, method.original_name]]
	end

	# For internal use only. Called at the end of every class and module body in an included file.
	def self.__closed__(owner, path = nil, line = nil)
		hook = CLOSED_MUTEX.synchronize do
			if CLOSED_MODULES[owner]
				:reopened
			else
				CLOSED_MODULES[owner] = true
				name = NAME_METHOD.bind_call(owner)

				if name.nil?
					:defined
				elsif path && defined_elsewhere?(name, path, line)
					:reopened
				elsif CLOSED_MODULE_NAMES.key?(name)
					:redefined
				else
					CLOSED_MODULE_NAMES[name] = true
					:defined
				end
			end
		end

		# The body may have included a module, which changes the ivars the class inherits.
		INHERITED_IVAR_TYPES.clear

		SEND_METHOD.bind_call(owner, hook)
	end

	# True when the constant was first defined somewhere other than the body that just closed, such as
	# a library class or one loaded before Empirical.init.
	private_class_method def self.defined_elsewhere?(name, path, line)
		location = CONST_SOURCE_LOCATION_METHOD.bind_call(Object, name)

		!location.nil? && location != [path, line]
	rescue ::NameError
		false
	end

	# The ivar types declared on a class and its ancestors. Literal props declared before Empirical
	# loaded never went through `has`, so they’re read from Literal.
	private_class_method def self.ivar_types_for(owner)
		INHERITED_IVAR_TYPES[owner] ||= owner.ancestors.reverse_each.with_object({}) do |ancestor, types|
			if Literal::Properties === ancestor
				ancestor.literal_properties.each do |property|
					types[:"@#{property.name}"] = property.type
				end
			end

			declared = IVAR_TYPE[ancestor]
			types.merge!(declared) if declared
		end
	end
end

class Object
	include Literal::Types
end

module Empirical::MethodTypes
	# The types of the typed parameters by name, or nil if the method wasn’t defined with `fun`.
	def parameter_types
		::Empirical.fun_types(self)&.parameter_types
	end

	# The return type, or nil if the method wasn’t defined with `fun`.
	def return_type
		::Empirical.fun_types(self)&.return_type
	end
end

Method.include(Empirical::MethodTypes)
UnboundMethod.include(Empirical::MethodTypes)

Empirical::CLASS_METHOD = Object.instance_method(:class)
Empirical::SINGLETON_CLASS_METHOD = Object.instance_method(:singleton_class)
Empirical::MODULE_EVAL_METHOD = Module.instance_method(:module_eval)
Empirical::PRIVATE_METHOD_DEFINED_METHOD = Module.instance_method(:private_method_defined?)
Empirical::PROTECTED_METHOD_DEFINED_METHOD = Module.instance_method(:protected_method_defined?)
Empirical::PUBLIC_METHOD = Module.instance_method(:public)
Empirical::PROTECTED_METHOD = Module.instance_method(:protected)
Empirical::PRIVATE_METHOD = Module.instance_method(:private)
Empirical::NAME_METHOD = Module.instance_method(:name)
Empirical::CONST_SOURCE_LOCATION_METHOD = Module.instance_method(:const_source_location)
Empirical::SEND_METHOD = BasicObject.instance_method(:__send__)
Empirical::EQUAL_METHOD = BasicObject.instance_method(:equal?)

class Module
	# Called when a class or module body in an included file closes for the first time.
	private def defined
	end

	# Called when the body of a class or module that has already been defined closes again.
	private def reopened
	end

	# Called instead of `defined` when a new class or module takes the name of an earlier one,
	# which is what happens when code is reloaded.
	private def redefined
		defined
	end

	# Declares the instance variables this class or module writes, and their types: `has name: String`.
	private def has(**types)
		types.each do |name, type|
			::Empirical.declare_ivar_type(self, :"@#{name}", type)
		end

		nil
	end
end

module Empirical::LiteralProperties
	def prop(name, type, ...)
		super.tap { has(name => type) }
	end
end

Literal::Properties.prepend(Empirical::LiteralProperties)
