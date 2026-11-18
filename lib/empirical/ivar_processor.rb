# frozen_string_literal: true

# Guards instance variable reads and type checks instance variable writes.
#
# Reads: `@context` holds the ivars that are known to be defined at this point, because an earlier read
# or write must have run. Those don’t need another guard. Anything that might not run (a branch, a loop
# body, the right of `&&`) is visited with a copy of the context that is thrown away afterwards.
#
# Writes: when the ivar has a `prop` in the same class body and the write is directly in an instance
# method, the check is inlined. Every other write is checked at runtime by `Empirical.__check_ivar__`.
class Empirical::IvarProcessor < Empirical::BaseProcessor
	WRITER_MACROS = Set[:attr_writer, :attr_accessor].freeze

	def initialize(...)
		super
		@props = {}
		@static_checks = []
		@inline = false
	end

	def visit_class_node(node)
		declarations = prop_declarations_in(node.body)
		props = declarations.to_h { |ivar, _type, ident| [ivar, "::Empirical::TypeStore::#{ident}"] }
		static_checks = []

		with_props(props, static_checks) { new_context { super } }

		store_prop_types(declarations, static_checks)
	end

	def visit_module_node(node)
		with_props({}) { new_context { super } }
	end

	def visit_singleton_class_node(node)
		with_props({}) { new_context { super } }
	end

	def visit_def_node(node)
		with_inline(node.receiver.nil?) { new_context { super } }
	end

	def visit_block_node(node)
		with_inline(false) { new_context { super } }
	end

	def visit_lambda_node(node)
		with_inline(false) { new_context { super } }
	end

	# A default only runs when the argument is omitted.
	def visit_optional_parameter_node(node)
		branch { super }
	end

	def visit_optional_keyword_parameter_node(node)
		branch { super }
	end

	# Nothing inside `defined?` is evaluated.
	def visit_defined_node(node)
	end

	def visit_instance_variable_read_node(node)
		name = node.name

		return if @context.include?(name)

		@context << name

		wrap(
			node.location.start_offset,
			node.location.end_offset,
			"(defined?(#{name}) ? ",
			" : (::Kernel.raise(::Empirical::NameError.new(self, :#{name}))))"
		)
	end

	def visit_instance_variable_write_node(node)
		check_statically(node)
		check_value(node.name, node.value)
		visit(node.value)
		@context << node.name
	end

	def visit_instance_variable_or_write_node(node)
		check_value(node.name, node.value)
		branch { visit(node.value) }
		@context << node.name
	end

	def visit_instance_variable_and_write_node(node)
		check_value(node.name, node.value)
		branch { visit(node.value) }
	end

	# `@a += 1` becomes `@a = check(@a + (1))`
	def visit_instance_variable_operator_write_node(node)
		name = node.name
		operator = node.binary_operator_loc
		value = node.value.location
		opening, closing = check(name, value.start_offset)

		@annotations << [operator.start_offset, operator.length, "= #{opening}#{name} #{node.binary_operator} "]
		wrap(value.start_offset, value.end_offset, "(", ")#{closing}")

		visit(node.value)
		@context << name
	end

	# `@a, @b = 1, 2` can’t be checked inline, so the ivars are checked straight after the assignment.
	def visit_multi_write_node(node)
		names = [*node.lefts, node.rest&.expression, *node.rights].filter_map do |target|
			target.name if Prism::InstanceVariableTargetNode === target
		end

		if names.any?
			offset = node.location.start_offset
			local = "__empirical_multi_write_#{offset}__"

			checks = names.each_with_index.map do |name, index|
				opening, closing = check(name, "#{offset}_#{index}")
				"#{opening}#{name}#{closing}"
			end

			wrap(
				node.location.start_offset,
				node.location.end_offset,
				"(#{local} = (",
				");#{checks.join(';')};#{local})"
			)
		end

		super

		@context.merge(names)
	end

	def visit_if_node(node)
		visit(node.predicate)

		branch { visit(node.statements) }
		branch { visit(node.subsequent) }
	end

	def visit_unless_node(node)
		visit(node.predicate)

		branch { visit(node.statements) }
		branch { visit(node.else_clause) }
	end

	def visit_case_node(node)
		visit(node.predicate)

		node.conditions.each do |condition|
			branch { visit(condition) }
		end

		branch { visit(node.else_clause) }
	end

	alias_method :visit_case_match_node, :visit_case_node

	def visit_and_node(node)
		visit(node.left)

		branch { visit(node.right) }
	end

	alias_method :visit_or_node, :visit_and_node

	def visit_while_node(node)
		visit(node.predicate)

		branch { visit(node.statements) }
	end

	alias_method :visit_until_node, :visit_while_node

	def visit_for_node(node)
		visit(node.collection)

		branch do
			visit(node.index)
			visit(node.statements)
		end
	end

	# An exception can interrupt the body anywhere, so nothing read in it is known to be defined afterwards.
	def visit_begin_node(node)
		return super unless node.rescue_clause || node.else_clause || node.ensure_clause

		branch { visit(node.statements) }
		branch { visit(node.rescue_clause) }
		branch { visit(node.else_clause) }
		branch { visit(node.ensure_clause) }
	end

	def visit_rescue_node(node)
		node.exceptions.each { |exception| visit(exception) }
		visit(node.reference)

		branch { visit(node.statements) }
		branch { visit(node.subsequent) }
	end

	def visit_rescue_modifier_node(node)
		branch { visit(node.expression) }
		branch { visit(node.rescue_expression) }
	end

	def visit_flip_flop_node(node)
		branch { visit(node.left) }
		branch { visit(node.right) }
	end

	def visit_call_node(node)
		# Ruby’s own writers set the ivar directly, so they’re replaced with ones that type check.
		if WRITER_MACROS.include?(node.name) && node.arguments && (node.receiver in nil | Prism::SelfNode)
			wrap(node.location.start_offset, node.location.end_offset, "::Empirical.__check_writers__(self, (", "))")
		end

		return super unless node.safe_navigation?

		visit(node.receiver)

		branch do
			visit(node.arguments)
			visit(node.block)
		end
	end

	# The value of `x ||= value` and `x &&= value` only runs some of the time.
	[:local_variable, :class_variable, :global_variable, :constant, :constant_path, :call, :index].each do |target|
		[:and, :or].each do |operator|
			define_method(:"visit_#{target}_#{operator}_write_node") do |node|
				node.compact_child_nodes.each do |child|
					if child.equal?(node.value)
						branch { visit(child) }
					else
						visit(child)
					end
				end
			end
		end
	end

	private def check_value(name, value)
		# `@a = 1, 2` and `@a = *list` are arrays without brackets
		brackets = Prism::ArrayNode === value && value.opening_loc.nil?
		opening, closing = check(name, value.location.start_offset)

		wrap(
			value.location.start_offset,
			value.location.end_offset,
			"#{opening}#{brackets ? '[' : '('}",
			"#{brackets ? ']' : ')'}#{closing}"
		)
	end

	# The opening and closing source to put around a value that is about to be written to an ivar.
	# The offset keeps the temporary unique, so it can’t collide with a local or with another check.
	private def check(name, offset)
		if (type = inline_type(name))
			local = "__empirical_ivar_#{offset}__"

			[
				"(#{type} === (#{local} = ",
				") ? #{local} : ::Kernel.raise(::Empirical::TypeError.ivar_type_error(name: :#{name}, value: #{local}, expected: #{type}, context: self)))",
			]
		else
			["::Empirical.__check_ivar__(self, :#{name}, ", ")"]
		end
	end

	private def inline_type(name)
		@props[name] if @inline
	end

	# Finds the `prop :name, Type` calls in a class body, as [ivar, type node, stored type name].
	private def prop_declarations_in(body)
		statements = (Prism::StatementsNode === body) ? body.body : []

		statements.filter_map do |statement|
			next unless statement in Prism::CallNode[
				name: :prop,
				receiver: nil,
				arguments: Prism::ArgumentsNode[arguments: [Prism::SymbolNode => name, type, *]]
			]

			[:"@#{name.unescaped}", type, "T_#{site}_#{type.location.start_offset}"]
		end
	end

	# Stores each prop’s type so writes can check against it inline. The static checks found in the
	# class run as the last prop is declared, once every type they mention has been stored.
	private def store_prop_types(declarations, static_checks)
		declarations.each_with_index do |(_ivar, type, ident), index|
			location = type.location

			if static_checks.any? && index == declarations.size - 1
				wrap(location.start_offset, location.end_offset, "::Empirical::StaticCheck.after(", ") { #{static_checks.join(';')} }")
			end

			wrap(location.start_offset, location.end_offset, "::Empirical::TypeStore.store(:#{ident}, (", "))")
		end
	end

	# A write whose value has a type that is known from the source: a literal, or another typed ivar.
	private def check_statically(node)
		name = node.name
		value = node.value
		expected = inline_type(name)

		return unless expected

		line = node.location.start_line

		case value
		in Empirical::LiteralNode
			return if value.slice.include?("\n")

			# `@a = 1, 2` is an array without brackets
			source = (Prism::ArrayNode === value && value.opening_loc.nil?) ? "[#{value.slice}]" : value.slice

			@static_checks << "::Empirical::StaticCheck.value(#{expected}, (#{source}), __FILE__, #{line}, #{"`#{name}` is assigned".inspect})"
		in Prism::InstanceVariableReadNode if (actual = inline_type(value.name))
			@static_checks << "::Empirical::StaticCheck.type(#{expected}, #{actual}, __FILE__, #{line}, #{"`#{name}` is assigned `#{value.name}`".inspect})"
		else
			# not known
		end
	end

	private def with_props(props, static_checks = [])
		original_props = @props
		original_static_checks = @static_checks
		@props = props
		@static_checks = static_checks
		with_inline(false) { yield }
	ensure
		@props = original_props
		@static_checks = original_static_checks
	end

	private def with_inline(inline)
		original_inline = @inline
		@inline = inline
		yield
	ensure
		@inline = original_inline
	end

	private def new_context
		original_context = @context

		@context = Set[]

		begin
			yield
		ensure
			@context = original_context
		end
	end

	private def branch
		original_context = @context
		@context = original_context.dup

		begin
			yield
		ensure
			@context = original_context
		end
	end
end
