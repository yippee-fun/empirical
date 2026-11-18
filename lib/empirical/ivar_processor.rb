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
	VALUE_LOCAL = "__empirical_ivar__"
	MULTI_WRITE_LOCAL = "__empirical_multi_write__"

	def initialize(...)
		super
		@props = {}
		@inline = false
	end

	def visit_class_node(node)
		with_props(props_declared_in(node.body)) { new_context { super } }
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

		@annotations << [operator.start_offset, operator.length, "= #{check_opening(name)}#{name} #{node.binary_operator} "]
		wrap(value.start_offset, value.end_offset, "(", ")#{check_closing(name)}")

		visit(node.value)
		@context << name
	end

	# `@a, @b = 1, 2` can’t be checked inline, so the ivars are checked straight after the assignment.
	def visit_multi_write_node(node)
		names = [*node.lefts, node.rest&.expression, *node.rights].filter_map do |target|
			target.name if Prism::InstanceVariableTargetNode === target
		end

		if names.any?
			checks = names.map { |name| "#{check_opening(name)}#{name}#{check_closing(name)}" }

			wrap(
				node.location.start_offset,
				node.location.end_offset,
				"(#{MULTI_WRITE_LOCAL} = (",
				");#{checks.join(';')};#{MULTI_WRITE_LOCAL})"
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

		wrap(
			value.location.start_offset,
			value.location.end_offset,
			"#{check_opening(name)}#{brackets ? '[' : '('}",
			"#{brackets ? ']' : ')'}#{check_closing(name)}"
		)
	end

	private def check_opening(name)
		if (type = inline_type(name))
			"(#{type} === (#{VALUE_LOCAL} = "
		else
			"::Empirical.__check_ivar__(self, :#{name}, "
		end
	end

	private def check_closing(name)
		if (type = inline_type(name))
			") ? #{VALUE_LOCAL} : ::Kernel.raise(::Empirical::TypeError.ivar_type_error(name: :#{name}, value: #{VALUE_LOCAL}, expected: #{type}, context: self)))"
		else
			")"
		end
	end

	private def inline_type(name)
		@props[name] if @inline
	end

	# Finds `prop :name, Type` calls in a class body and stores each type so writes can check against it inline.
	private def props_declared_in(body)
		statements = (Prism::StatementsNode === body) ? body.body : []

		statements.each_with_object({}) do |statement, props|
			next unless statement in Prism::CallNode[
				name: :prop,
				receiver: nil,
				arguments: Prism::ArgumentsNode[arguments: [Prism::SymbolNode => name, type, *]]
			]

			ident = "T_#{site}_#{type.location.start_offset}"

			wrap(type.location.start_offset, type.location.end_offset, "::Empirical::TypeStore.store(:#{ident}, (", "))")

			props[:"@#{name.unescaped}"] = "::Empirical::TypeStore::#{ident}"
		end
	end

	private def with_props(props)
		original_props = @props
		@props = props
		with_inline(false) { yield }
	ensure
		@props = original_props
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
