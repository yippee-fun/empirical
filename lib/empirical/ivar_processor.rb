# frozen_string_literal: true

class Empirical::IvarProcessor < Empirical::BaseProcessor
	def visit_class_node(node)
		new_context { super }
	end

	def visit_module_node(node)
		new_context { super }
	end

	def visit_instance_variable_write_node(node)
		@annotations << [
			node.name_loc.start_offset,
			0,
			"::Empirical::SET_IVAR_METHOD.bind_call(self, :",
		]

		@annotations << [
			(start = node.name_loc.end_offset),
			node.value.location.start_offset - start,
			", ",
		]

		@annotations << [
			node.location.end_offset,
			0,
			")",
		]
	end

	def visit_block_node(node)
		new_context { super }
	end

	def visit_singleton_class_node(node)
		new_context { super }
	end

	def visit_def_node(node)
		new_context { super }
	end

	def visit_if_node(node)
		visit(node.predicate)

		branch { visit(node.statements) }
		branch { visit(node.subsequent) }
	end

	def visit_case_node(node)
		visit(node.predicate)

		node.conditions.each do |condition|
			branch { visit(condition) }
		end

		branch { visit(node.else_clause) }
	end

	def visit_defined_node(node)
		value = node.value

		return if Prism::InstanceVariableReadNode === value

		super
	end

	def visit_instance_variable_read_node(node)
		name = node.name

		unless @context.include?(name)
			location = node.location

			@context << name

			@annotations.push(
				[location.start_character_offset, 0, "(defined?(#{name}) ? "],
				[location.end_character_offset, 0, " : (::Kernel.raise(::Empirical::NameError.new(self, :#{name}))))"]
			)
		end

		super
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
