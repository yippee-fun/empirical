# frozen_string_literal: true

# Turns a parsed Fun into source edits that rewrite it as a plain `def` with inline type checks.
# Edits never add or remove lines, so line numbers in the output match the original source.
class Empirical::FunGenerator
	RESERVED_WORDS = Set[
		:alias, :and, :begin, :break, :case, :class, :def, :defined?, :do, :else, :elsif, :end, :ensure,
		:false, :for, :if, :in, :module, :next, :nil, :not, :or, :redo, :rescue, :retry, :return, :self,
		:super, :then, :true, :undef, :unless, :until, :when, :while, :yield,
	].freeze

	# return_local holds the value being returned. It’s named from the source offset so it can’t collide
	# with a local. return_check is the statement that checks it, for methods with a typed return.
	attr_reader :annotations, :return_local, :return_check

	def initialize(fun, source:, site:, ivar_types: {})
		@fun = fun
		@source = source
		@site = site
		@ivar_types = ivar_types
		@annotations = []
		@checks = []
		@stores = []
		@parameter_types = []
		@parameter_idents = {}
		@return_local = "__empirical_return_#{fun.call.location.start_offset}__"
		@receiver_local = "__empirical_receiver_#{fun.call.location.start_offset}__"
		@return_check = nil
	end

	def call
		fun = @fun
		body = fun.body

		# The `begin` keeps what follows the `def` under a modifier like `if`, and evaluates to the method name like a `def`.
		replace(fun.call.message_loc.start_offset, fun.call.message_loc.end_offset, "begin;def")

		fun.parameters.each { |parameter| rewrite(parameter) }

		# Everything between the signature and the body (` => ReturnType do |defaults|`) becomes the checks.
		replace(
			fun.signature.location.end_offset,
			body.parameters ? body.parameters.location.end_offset : body.opening_loc.end_offset,
			";#{[*@checks, body_opening].join(';')};"
		)

		insert(body.closing_loc.start_offset, ";#{body_closing};")
		insert(body.closing_loc.end_offset, ";#{[*@stores, *static_checks, declaration].join(';')};end")

		self
	end

	# Run after the types are stored, so mistakes visible in the source are reported when the file loads.
	private def static_checks
		Empirical::FunChecker.new(
			@fun,
			parameter_types: @parameter_idents,
			return_type: (return_type if @fun.return_type.kind == :typed),
			ivar_types: @ivar_types,
		).statements
	end

	# Registers the types under the location `Method#source_location` will report for the `def`.
	private def declaration
		lines_since_def = @fun.body.closing_loc.start_line - @fun.call.message_loc.start_line

		"::Empirical.__declare_fun_types__(__FILE__, __LINE__ - #{lines_since_def}, :#{method_name}, {#{@parameter_types.join(', ')}}, #{return_type})"
	end

	private def return_type
		@return_type ||= case @fun.return_type.kind
		in :void
			"::Literal::Types._Void"
		in :never
			"::Literal::Types._Never"
		in :itself
			"::Empirical::Itself"
		in :typed
			store(@fun.return_type.node, @fun.return_type.source)
		end
	end

	private def rewrite(parameter)
		name = parameter.name
		node = parameter.node
		type = parameter.type

		case parameter.kind
		in :untyped
			return
		in :positional_splat
			insert(node.key.location.start_offset, "*")
			replace(node.key.closing_loc.start_offset, type.location.end_offset, "")
		in :keyword_splat
			insert(node.key.location.start_offset, "**")
			replace(node.key.closing_loc.start_offset, type.location.end_offset, "")
		in :keyword
			key = node.key

			# Drop the `?` from `name?:`
			replace(key.value_loc.end_offset - 1, key.value_loc.end_offset, "") if parameter.optional

			if parameter.default
				replace(type.location.start_offset, type.location.end_offset, parameter.default)
			elsif parameter.optional
				replace(type.location.start_offset, type.location.end_offset, "nil")
			else
				replace(key.location.end_offset, type.location.end_offset, "")
			end
		end

		ident = store(type, parameter.type_source)
		@parameter_types << "#{name}: #{ident}"
		@parameter_idents[name] = ident
		value = RESERVED_WORDS.include?(name) ? "::Kernel.binding.local_variable_get(:#{name})" : name

		@checks << "::Kernel.raise(::Empirical::TypeError.argument_type_error(name: :#{name}, value: #{value}, expected: #{ident}, method_name: :#{method_name}, context: self)) unless #{ident} === #{value}"
	end

	private def method_name
		@fun.signature.name
	end

	private def body_opening
		case @fun.return_type.kind
		in :typed
			"#{@return_local} = begin"
		in :itself
			# An early return can happen inside `instance_eval`, where `self` is something else.
			"#{@receiver_local} = self;#{@return_local} = begin"
		in :void | :never
			"begin"
		end
	end

	private def body_closing
		case @fun.return_type.kind
		in :void
			"end;::Empirical::Void"
		in :never
			"end;::Kernel.raise(::Empirical::NeverError.new)"
		in :itself
			@return_check = "::Kernel.raise(::Empirical::TypeError.itself_return_error(value: #{@return_local}, method_name: :#{method_name}, context: #{@receiver_local})) unless ::Empirical::EQUAL_METHOD.bind_call(#{@receiver_local}, #{@return_local})"

			"end;#{@return_check};#{@return_local}"
		in :typed
			ident = return_type

			@return_check = "::Kernel.raise(::Empirical::TypeError.return_type_error(value: #{@return_local}, expected: #{ident}, method_name: :#{method_name}, context: self)) unless #{ident} === #{@return_local}"

			"end;#{@return_check};#{@return_local}"
		end
	end

	# Types are evaluated once, where the method is defined, and read back from a constant inside the method.
	private def store(node, source)
		name = "T_#{@site}_#{node.location.start_offset}"
		@stores << "::Empirical::TypeStore.store(:#{name}, (#{source}))"
		"::Empirical::TypeStore::#{name}"
	end

	private def insert(offset, string)
		@annotations << [offset, 0, string]
	end

	# Keeps the newlines of whatever it replaces so the following lines don’t move.
	private def replace(start_offset, end_offset, string)
		length = end_offset - start_offset
		newlines = @source.byteslice(start_offset, length).count("\n")
		@annotations << [start_offset, length, "#{string}#{"\n" * newlines}"]
	end
end
